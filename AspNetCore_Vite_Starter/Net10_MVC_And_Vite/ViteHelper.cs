using System.Diagnostics;
using System.Net.NetworkInformation;
using System.Text;
using Microsoft.AspNetCore.SpaServices;

namespace $safeprojectname$
{
    /// <summary>
    /// Vite 開發伺服器輔助類別，用於在 ASP.NET Core 應用程式中整合 Vite 開發伺服器
    /// </summary>
    public static class ViteHelper
    {
        /// <summary>
        /// 判斷當前操作系統是否為 Windows
        /// </summary>
        private static bool PlatformIsWindows => OperatingSystem.IsWindows();

        /// <summary>
        /// Vite 日誌記錄器
        /// </summary>
        private static ILogger? ViteLogger;

        /// <summary>
        /// 添加與 Vite 托管的 Vue 應用程式的連接
        /// 根據 <paramref name="spa"/> 上的 <seealso cref="SpaOptions"/> 進行配置
        /// 注意：（首次運行時將在 Vue 應用程式目錄中創建 devcert.pfx 和 vite.config.js）
        /// </summary>
        /// <param name="port">Vite 托管端口</param>
        /// <param name="sourcePath">Vite 應用程式源代碼路徑</param>
        public static void UseViteDevelopmentServer(this ISpaBuilder spa, int? port = null, string? sourcePath = null)
        {            // 如果未安裝 Node.js，則拋出錯誤
            EnsureNodeJSAlreadyInstalled();

            // 設置默認托管端口
            if (!port.HasValue)
                port = 5173;

            spa.Options.DevServerPort = port.Value;

            if (!string.IsNullOrWhiteSpace(sourcePath))
                spa.Options.SourcePath = sourcePath;
            else if (string.IsNullOrWhiteSpace(spa.Options.SourcePath))
                throw new ArgumentException("必須指定 SPA 客戶端應用程式路徑", nameof(sourcePath));

            Uri devServerEndpoint = new Uri($"https://localhost:{spa.Options.DevServerPort}");
            IWebHostEnvironment? webHostEnvironment = spa.ApplicationBuilder.ApplicationServices.GetService<IWebHostEnvironment>();
            ViteLogger = spa.ApplicationBuilder.ApplicationServices.GetService<ILoggerFactory>()?.CreateLogger("Vite");            // 如果端口未被使用，則啟動 Vite 開發伺服器
            if (!CheckPortInUsed(spa.Options.DevServerPort))
            {

                // 導出開發憑證
                string spaFolder = Path.Combine(webHostEnvironment?.ContentRootPath ?? string.Empty, spa.Options.SourcePath);
                if (!Directory.Exists(spaFolder))
                    throw new DirectoryNotFoundException(spaFolder);

                string viteConfigPath = GetViteConfigFile(spaFolder);

                string devCert = Path.Combine(spaFolder, "devcert.pfx");
                string serverOptionFile = Path.Combine(spaFolder, $"serverOption{new FileInfo(viteConfigPath).Extension}");                // 檢查開發憑證是否存在
                if (!File.Exists(serverOptionFile) || !File.Exists(devCert))
                {
                    string pwd = CreateCertPfxKey(devCert);

                    // 創建伺服器選項文件
                    File.WriteAllText(serverOptionFile, BuildServerOption(devCert, pwd));
                    ViteLogger?.LogInformation("創建 Vite 配置文件: {ServerOptionFile}", serverOptionFile);

                    InjectionViteConfig(viteConfigPath, serverOptionFile);
                }


                EnsureNodeModuleAlreadyInstalled(spa.Options.SourcePath);                // 啟動 Vite 開發伺服器
                RunDevServer(spa.Options.SourcePath, spa.Options.DevServerPort, spa.Options.StartupTimeout);
            }

            spa.UseProxyToSpaDevelopmentServer(devServerEndpoint);
        }

        /// <summary>
        /// 注入 vite.config 文件以使用 serverOption 文件
        /// </summary>
        private static void InjectionViteConfig(string viteConfigPath, string serverOptionFile)
        {
            FileInfo optionFile = new FileInfo(serverOptionFile);
            string serverOption = optionFile.Name[..^optionFile.Extension.Length];
            List<string> data = File.ReadAllLines(viteConfigPath).ToList();            // 已經注入過則不再注入
            if (data.Any(x => x.Contains($"./{serverOption}")))
                return;

            data.Insert(0, $"import serverOption from './{serverOption}'");

            int exportDefaultLine = data.FindIndex(x => x.Contains("export default"));
            if (exportDefaultLine == -1)
                return;

            data.Insert(exportDefaultLine + 1, "  server : serverOption,");

            File.WriteAllLines(viteConfigPath, data);
        }

        /// <summary>
        /// 獲取 vite.config 文件路徑（支援 .ts 和 .js 格式）
        /// </summary>
        private static string GetViteConfigFile(string rootPath)
        {
            string configFile = Directory.GetFiles(rootPath)
                .Where(x =>
                 {
                     FileInfo file = new FileInfo(x);
                     string fileName = file.Name[..^file.Extension.Length];
                     return fileName.Equals("vite.config", StringComparison.OrdinalIgnoreCase);
                 }).Single();
            return configFile;
        }

        /// <summary>
        /// 構建 Vite HTTPS 伺服器選項
        /// </summary>
        private static string BuildServerOption(string certfile, string pass)
        {
            // 使用 InvariantCulture 的 AppendLine 避免地區設定影響（CA1305）
            StringBuilder sb = new StringBuilder();
            sb.AppendLine(System.Globalization.CultureInfo.InvariantCulture, $"");
            sb.AppendLine(System.Globalization.CultureInfo.InvariantCulture, $"");
            sb.AppendLine(System.Globalization.CultureInfo.InvariantCulture, $"export default {{");
            sb.AppendLine(System.Globalization.CultureInfo.InvariantCulture, $"https: {{ pfx: '{Path.GetFileName(certfile)}', passphrase: '{pass}' }}");
            sb.AppendLine(System.Globalization.CultureInfo.InvariantCulture, $"}}");
            sb.AppendLine(System.Globalization.CultureInfo.InvariantCulture, $"");
            return sb.ToString();
        }

        /// <summary>
        /// 檢查指定端口是否已被使用
        /// </summary>
        /// <param name="port">要檢查的端口號</param>
        /// <returns>如果端口已被使用則返回 true，否則返回 false</returns>
        private static bool CheckPortInUsed(int port)
            => IPGlobalProperties.GetIPGlobalProperties()
                .GetActiveTcpListeners()
                .Select(x => x.Port)
                .Contains(port);

        /// <summary>
        /// 如果 'node_modules' 不存在則執行 'npm install'
        /// </summary>
        /// <param name="sourcePath">源代碼路徑</param>
        private static void EnsureNodeModuleAlreadyInstalled(string sourcePath)
        {
            // 檢查 Node_Modules 是否存在
            if (!Directory.Exists(Path.Combine(sourcePath, "node_modules")))
            {
                ViteLogger?.LogWarning("找不到 node_modules，執行 npm install...");

                // 安裝 node modules
                Process? ps = Process.Start(new ProcessStartInfo()
                {
                    FileName = PlatformIsWindows ? "cmd" : "npm",
                    Arguments = $"{(PlatformIsWindows ? "/c npm " : "")}install",
                    WorkingDirectory = sourcePath,
                    RedirectStandardError = true,
                    RedirectStandardInput = true,
                    RedirectStandardOutput = true,
                    UseShellExecute = false,
                });
                ps?.WaitForExit();
                ViteLogger?.LogWarning("npm install 完成。");
            }
        }

        /// <summary>
        /// 如果 'node --version' 命令出錯，則拋出異常
        /// </summary>
        /// <exception cref="Exception">當 Node.js 未安裝時拋出異常</exception>
        private static void EnsureNodeJSAlreadyInstalled()
        {
            Process? ps = Process.Start(new ProcessStartInfo()
            {
                FileName = PlatformIsWindows ? "cmd" : "node",
                Arguments = $"{(PlatformIsWindows ? "/c node " : "")}--version",
                //WorkingDirectory = /*SourcePath*/,
                RedirectStandardError = true,
                RedirectStandardInput = true,
                RedirectStandardOutput = true,
                UseShellExecute = false,
            });

            ps?.WaitForExit();

            if (ps?.ExitCode == 0)
                return;

            throw new InvalidOperationException("Node.js is required to build and run this project. To continue, please install Node.js from https://nodejs.org/, and then restart your command prompt or IDE.");

        }

        /// <summary>
        /// Create pfx key and return password
        /// </summary>
        private static string CreateCertPfxKey(string fileName)
        {
            string pfxPassword = Guid.NewGuid().ToString("N");
            ViteLogger?.LogInformation("Exporting dotnet dev cert to {FileName} for Vite", fileName);
            ViteLogger?.LogDebug("Export password: {PfxPassword}", pfxPassword);
            ProcessStartInfo certExport = new ProcessStartInfo
            {
                FileName = PlatformIsWindows ? "cmd" : "dotnet",
                Arguments = $"{(PlatformIsWindows ? "/c dotnet " : "")}dev-certs https -v -ep {fileName} -p {pfxPassword}",
                RedirectStandardError = true,
                RedirectStandardInput = true,
                RedirectStandardOutput = true,
                UseShellExecute = false,
            };

            Process? exportProcess = Process.Start(certExport);
            exportProcess?.WaitForExit();
            if (exportProcess?.ExitCode == 0)
                ViteLogger?.LogInformation("Dev cert export output: {Output}", exportProcess.StandardOutput.ReadToEnd());
            else
                ViteLogger?.LogError("Dev cert export error: {Error}", exportProcess?.StandardError.ReadToEnd());

            return pfxPassword;
        }

        /// <summary>
        /// 執行開發伺服器
        /// </summary>
        /// <param name="sourcePath"></param>
        /// <param name="port"></param>
        /// <param name="timeout"></param>
        /// <exception cref="TimeoutException"></exception>
        private static void RunDevServer(string sourcePath, int port, TimeSpan timeout)
        {
            string runningPort = $" -- --port {port}";
            ProcessStartInfo processInfo = new ProcessStartInfo
            {
                FileName = PlatformIsWindows ? "cmd" : "npm",
                Arguments = $"{(PlatformIsWindows ? "/c npm " : "")}run dev{runningPort}",
                WorkingDirectory = sourcePath,
                RedirectStandardError = true,
                RedirectStandardInput = true,
                RedirectStandardOutput = true,
                UseShellExecute = false,
            };
            Process? process = Process.Start(processInfo);
            TaskCompletionSource<int> tcs = new TaskCompletionSource<int>();

            _ = Task.Run(() =>
            {
                try
                {
                    string? line;
                    while ((line = process?.StandardOutput.ReadLine()?.Trim()) != null)
                    {
                        // Wait for done message
                        if (!string.IsNullOrEmpty(line))
                        {
                            ViteLogger?.LogInformation("{Line}", line);
                            if (!tcs.Task.IsCompleted && line.Contains("VITE", StringComparison.OrdinalIgnoreCase))
                                if (line.Contains("ready in", StringComparison.OrdinalIgnoreCase) || // for VITE v3
                                    line.Contains("Dev server running at:", StringComparison.OrdinalIgnoreCase)) // for VITE v2
                                {
                                    tcs.SetResult(1);
                                }
                        }
                    }
                }
                catch (EndOfStreamException ex)
                {
                    ViteLogger?.LogError(ex, "'npm run dev' StandardOutput failed");
                    tcs.SetException(new InvalidOperationException("'npm run dev' failed.", ex));
                }
            });

            _ = Task.Run(() =>
            {
                try
                {
                    string? line;
                    while ((line = process?.StandardError.ReadLine()?.Trim()) != null)
                    {
                        ViteLogger?.LogError("{Line}", line);
                    }
                }
                catch (EndOfStreamException ex)
                {
                    ViteLogger?.LogError(ex, "'npm run dev' StandardError failed");
                    tcs.SetException(new InvalidOperationException("'npm run dev' failed.", ex));
                }
            });

            if (!tcs.Task.Wait(timeout))
            {
                throw new TimeoutException();
            }
        }
    }
}
