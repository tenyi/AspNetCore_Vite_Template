# VSIX 範本打包指南（AspNetCore_Vite_Starter）

> 本文件說明如何把 `Net10_*` 範例專案 + `ClientApps/` 前端，打包成 Visual Studio 專案範本 ZIP，並整合進 VSIX 擴充套件。
>
> 適用對象：維護者。涵蓋：範本參數機制、12 個 ZIP 對照、自動化打包腳本、VSIX 宣告同步、驗證、常見陷阱。

---

## 1. 整體概念

`AspNetCore_Vite_Starter` 是一支 **VSIX 擴充套件**，本身不寫邏輯，只透過 `source.extension.vsixmanifest` 的 `<Assets>` 打包 **12 個專案範本 ZIP**。使用者在 Visual Studio「新增專案」對話框看到並選用的，就是這 12 個 ZIP。

每個 ZIP = **1 種後端風格 × 1 種前端**：

- 後端 3 種：`Controllers` / `MinimalAPI` / `MVC`（對應 3 個 `Net10_*` 範例）
- 前端 4 種：`Vue(JS)` / `Vue(TS)` / `React(JS)` / `React(TS)`（對應 `ClientApps/` 四個目錄）
- 3 × 4 = **12 個** ZIP（全組合齊備，每個後端都搭到所有前端）。

---

## 2. 目錄角色

| 路徑 | 角色 | 打包時用途 |
|---|---|---|
| `AspNetCore_Vite_Starter/Net10_Controller_And_Vite/` | 後端範例（Controllers 風格） | 提供後端 `.cs`/`.csproj`/`Properties` 等檔案 |
| `AspNetCore_Vite_Starter/Net10_MinimalAPI_And_Vite/` | 後端範例（MinimalAPI 風格） | 同上 |
| `AspNetCore_Vite_Starter/Net10_MVC_And_Vite/` | 後端範例（MVC 風格，含 `Pages/`） | 同上 |
| `AspNetCore_Vite_Starter/ClientApps/{vue-js,vue-ts,react-js,react-ts}/` | **前端權威來源**（無 `node_modules`） | 提供前端 `ClientApp/` 內容 |
| `scripts/build-zips.ps1` | **自動化打包腳本** | 從上述來源批次產生 12 個 ZIP |
| `AspNetCore_Vite_Starter/AspNetCore_Vite_Starter/ProjectTemplates/` | 12 個 ZIP 的存放處 | 打包產出位置 |
| `AspNetCore_Vite_Starter/AspNetCore_Vite_Starter/AspNetCore_Vite_Starter.csproj` | VSIX 容器專案 | 用 `<Content Include>` 宣告要打包的 ZIP |
| `AspNetCore_Vite_Starter/AspNetCore_Vite_Starter/source.extension.vsixmanifest` | VSIX 資訊清單 | 用 `<Assets>` 宣告每個範本 |

> ⚠️ **兩套副本，不要混淆**
> - `Net10_*` 範例專案是**活的開發版**：namespace 寫死成 `Net10_XXX_And_Vite`，可直接 F5 執行。
> - ZIP 範本是**範本版**：namespace 必須換成 `$safeprojectname$`，否則每個從範本開出來的專案都會叫 `Net10_XXX_And_Vite`。
>
> 打包 = 複製範例 → 在副本上轉換 namespace → 壓縮。**絕不可改原始 `Net10_*` 範例的 namespace**（會破壞 F5）。

---

## 3. 核心機制：Visual Studio 範本參數

VS 專案範本用 **`$參數名$`**（前後各一個 `$`）當預留位置，建立專案時自動替換成使用者輸入的名稱。VS 2026 完全相容此傳統 `.vstemplate` 機制。

### 3.1 常用參數

| 參數 | 說明 | 範例（使用者輸入 `My-App 1`） |
|---|---|---|
| `$projectname$` | 原始名稱，**可能含空格/連字號/數字開頭**，不能當識別碼 | `My-App 1` |
| `$safeprojectname$` | ✅ 清理成合法 C# 識別碼，**namespace/類別專用** | `My_App_1` |
| `$rootnamespace$` | 根命名空間（通常 = `$safeprojectname$`） | `My_App_1` |
| `$specifiedsafeprojectname$` | 使用者若自訂 rootnamespace 則為該值 | `My_App_1` |

其他內建：`$time$ $year$ $year:yyyy$ $user$ $userdomain$ $machine$ $clrversion$ $registeredorganization$ $runtimeversion$` 等。

> **namespace 一律用 `$safeprojectname$`，不要用 `$projectname$`。** 後者可能含不合法字元導致編譯失敗。

### 3.2 啟用替換的兩個必要步驟

**步驟 A — 在原始碼裡寫參數：**
```csharp
namespace $safeprojectname$
{
    public static class ViteHelper { ... }
}
```

**步驟 B — 在 `.vstemplate` 對該檔案設 `ReplaceParameters="true"`：**
只有標記的檔案才會做替換。
```xml
<Project TargetFileName="..." File="Net10_MVC_And_Vite.csproj" ReplaceParameters="true">
  <ProjectItem ReplaceParameters="true" TargetFileName="ViteHelper.cs">ViteHelper.cs</ProjectItem>
  <ProjectItem ReplaceParameters="false" TargetFileName="favicon.ico">favicon.ico</ProjectItem>
</Project>
```

> `ReplaceParameters` 設定原則：
> - `.cs` / `.cshtml` / `.csproj` / `appsettings*.json` / `package.json`（要替換 `"name"`） → **`true`**
> - 二進位檔（`.png .ico .svg`）、不需要替換的靜態檔（`README.md`、`.vue`、`.css`） → **`false`**
> - 注意：`package.json` 的 npm script 不會用 `$`，設 `true` 安全；但若檔案含字面 `$xxx$` 形式字串會被誤替換，需個別檢查。

---

## 4. 12 個 ZIP 對照表

| # | ZIP 檔名 | 後端範例來源 | 前端來源 |
|---|---|---|---|
| 1 | `Vite_ReactJS_And_Net10_Controllers.zip` | `Net10_Controller_And_Vite` | `ClientApps/react-js` |
| 2 | `Vite_ReactJS_And_Net10_MinimalAPI.zip` | `Net10_MinimalAPI_And_Vite` | `ClientApps/react-js` |
| 3 | `Vite_ReactJS_And_Net10_MVC.zip` | `Net10_MVC_And_Vite` | `ClientApps/react-js` |
| 4 | `Vite_ReactTS_And_Net10_Controllers.zip` | `Net10_Controller_And_Vite` | `ClientApps/react-ts` |
| 5 | `Vite_ReactTS_And_Net10_MinimalAPI.zip` | `Net10_MinimalAPI_And_Vite` | `ClientApps/react-ts` |
| 6 | `Vite_ReactTS_And_Net10_MVC.zip` | `Net10_MVC_And_Vite` | `ClientApps/react-ts` |
| 7 | `Vite_VueJS_And_Net10_Controllers.zip` | `Net10_Controller_And_Vite` | `ClientApps/vue-js` |
| 8 | `Vite_VueJS_And_Net10_MinimalAPI.zip` | `Net10_MinimalAPI_And_Vite` | `ClientApps/vue-js` |
| 9 | `Vite_VueJS_And_Net10_MVC.zip` | `Net10_MVC_And_Vite` | `ClientApps/vue-js` |
| 10 | `Vite_VueTS_And_Net10_Controllers.zip` | `Net10_Controller_And_Vite` | `ClientApps/vue-ts` |
| 11 | `Vite_VueTS_And_Net10_MinimalAPI.zip` | `Net10_MinimalAPI_And_Vite` | `ClientApps/vue-ts` |
| 12 | `Vite_VueTS_And_Net10_MVC.zip` | `Net10_MVC_And_Vite` | `ClientApps/vue-ts` |

ZIP 檔名公式：`Vite_<Frontend><Js|Ts>_And_Net10_<Backend>.zip`，與 `<Name>` / `<DefaultName>` 一致。

---

## 5. 打包流程

> ✅ **建議直接用 `scripts/build-zips.ps1` 自動打包**（§5.5）。手動流程（§5.1–§5.4）保留作為理解原理用。

### 5.1 建立乾淨工作資料夾

每次打包都先建一個**全新的暫存資料夾**（避免殘留），命名任意，例如 `Build_Vite_VueTS_And_Net10_MVC`。

### 5.2 組裝檔案（後端 + 前端 → 工作資料夾根目錄）

把後端範例的檔案複製進工作資料夾根目錄，**排除 `bin/`、`obj/`、既有的 `ClientApp/`**：

```
工作資料夾\
├─ Net10_MVC_And_Vite.csproj
├─ Program.cs
├─ ViteHelper.cs
├─ WeatherForecast.cs
├─ appsettings.json
├─ appsettings.Development.json
├─ Properties\
│   └─ launchSettings.json
├─ Controllers\
│   └─ WeatherForecastController.cs
├─ Pages\
│   ├─ _ViewImports.cshtml
│   ├─ Error.cshtml
│   └─ Error.cshtml.cs
└─ ClientApp\          ← 從 ClientApps/vue-ts 整包複製過來（不含 node_modules）
    ├─ package.json
    ├─ vite.config.ts
    ├─ index.html
    ├─ src\
    └─ public\
```

> **前端來源一律用 `ClientApps/<frontend>/`**，不要用 `Net10_*` 範例內既有的 `ClientApp/`（前者才是權威、乾淨、統一的來源）。

### 5.3 轉換 namespace → `$safeprojectname$`（只在工作副本上做）

把該後端的 **namespace 根字串**整個換成 `$safeprojectname$`，尾綴（`.Controllers`、`.Pages`）保留：

| 檔案 | 原始（寫死） | 改成（範本） |
|---|---|---|
| `ViteHelper.cs` | `namespace Net10_MVC_And_Vite` | `namespace $safeprojectname$` |
| `Program.cs` | `using Net10_MVC_And_Vite;` | `using $safeprojectname$;` |
| `WeatherForecast.cs` | `namespace Net10_MVC_And_Vite` | `namespace $safeprojectname$` |
| `Controllers/WeatherForecastController.cs` | `namespace Net10_MVC_And_Vite.Controllers` | `namespace $safeprojectname$.Controllers` |
| `Pages/Error.cshtml.cs` | `namespace Net10_MVC_And_Vite.Pages` | `namespace $safeprojectname$.Pages` |
| `Pages/_ViewImports.cshtml` | `@namespace Net10_MVC_And_Vite.Pages` | `@namespace $safeprojectname$.Pages` |
| `Pages/Error.cshtml` | `@using Net10_MVC_And_Vite.Pages` | `@using $safeprojectname$.Pages` |

> **通用規則**：對 Controller/MinimalAPI 範例，把 `Net10_Controller_And_Vite` / `Net10_MinimalAPI_And_Vite` 全域替換成 `$safeprojectname$`；MVC 同理換 `Net10_MVC_And_Vite`。
>
> 用 PowerShell 在工作副本上批次替換（**務必先確認只改到副本**）：
> ```powershell
> $work = "D:\...\Build_Vite_VueTS_And_Net10_MVC"
> $root = "Net10_MVC_And_Vite"   # 換成當前後端的 namespace 根
> $files = Get-ChildItem -Path $work -Recurse -Include *.cs,*.cshtml
> foreach ($f in $files) {
>     (Get-Content $f.FullName) -replace [regex]::Escape($root), '$safeprojectname$' |
>         Set-Content $f.FullName -Encoding UTF8
> }
> ```

> 💡 **MVC 範例已知 bug**：`Net10_MVC_And_Vite/` 本機有些檔案（`Controllers/WeatherForecastController.cs`、`Pages/Error.cshtml.cs`、`Pages/_ViewImports.cshtml`、`Pages/Error.cshtml`）把 namespace 寫死成 `Net10_MVC_And_Vite`，不像其他後端範例用 `$safeprojectname$`。`build-zips.ps1` 在打包時會一併取代掉這些字串，所以 ZIP 內是正確的；但**直接 F5 執行本機 MVC 範例時，這些檔案的 namespace 仍會被硬編碼成 `Net10_MVC_And_Vite`**，這對開發執行沒影響（剛好與專案資料夾名一致），但若要修，建議把本機檔案也改回 `$safeprojectname$`。

### 5.4 在工作資料夾根目錄建立 `.vstemplate`

檔名慣用 `MyTemplate.vstemplate`，內容如下（以 MVC 為例，其餘後端把對應檔案/資料夾調整即可）：

```xml
<VSTemplate Version="3.0.0" xmlns="http://schemas.microsoft.com/developer/vstemplate/2005" Type="Project">
  <TemplateData>
    <Name>Vite_VueTS_And_Net10_MVC</Name>
    <Description>ASP.NET Core 10 (MVC) + Vue + TypeScript + Vite DevServer</Description>
    <ProjectType>CSharp</ProjectType>
    <SortOrder>1000</SortOrder>
    <CreateNewFolder>true</CreateNewFolder>
    <DefaultName>Vite_VueTS_And_Net10_MVC</DefaultName>
    <ProvideDefaultName>true</ProvideDefaultName>
    <LocationField>Enabled</LocationField>
    <EnableLocationBrowseButton>true</EnableLocationBrowseButton>
    <CreateInPlace>true</CreateInPlace>
    <Icon>__TemplateIcon.png</Icon>
  </TemplateData>
  <TemplateContent>
    <Project TargetFileName="Net10_MVC_And_Vite.csproj" File="Net10_MVC_And_Vite.csproj" ReplaceParameters="true">
      <Folder Name="Properties" TargetFolderName="Properties">
        <ProjectItem ReplaceParameters="true" TargetFileName="launchSettings.json">launchSettings.json</ProjectItem>
      </Folder>
      <Folder Name="Controllers" TargetFolderName="Controllers">
        <ProjectItem ReplaceParameters="true" TargetFileName="WeatherForecastController.cs">WeatherForecastController.cs</ProjectItem>
      </Folder>
      <Folder Name="Pages" TargetFolderName="Pages">
        <ProjectItem ReplaceParameters="true" TargetFileName="_ViewImports.cshtml">_ViewImports.cshtml</ProjectItem>
        <ProjectItem ReplaceParameters="true" TargetFileName="Error.cshtml">Error.cshtml</ProjectItem>
        <ProjectItem ReplaceParameters="true" TargetFileName="Error.cshtml.cs">Error.cshtml.cs</ProjectItem>
      </Folder>
      <Folder Name="ClientApp" TargetFolderName="ClientApp">
        <!-- 依照 ClientApps/<frontend> 實際結構逐檔列出；原則：程式碼/設定 true、二進位 false -->
        <ProjectItem ReplaceParameters="true" TargetFileName="package.json">package.json</ProjectItem>
        <ProjectItem ReplaceParameters="true" TargetFileName="vite.config.ts">vite.config.ts</ProjectItem>
        <ProjectItem ReplaceParameters="true" TargetFileName="index.html">index.html</ProjectItem>
        <ProjectItem ReplaceParameters="true" TargetFileName="tsconfig.json">tsconfig.json</ProjectItem>
        <!-- ...其餘 src/、public/ 下檔案逐一列出... -->
      </Folder>
      <ProjectItem ReplaceParameters="true" TargetFileName="appsettings.json">appsettings.json</ProjectItem>
      <ProjectItem ReplaceParameters="true" TargetFileName="appsettings.Development.json">appsettings.Development.json</ProjectItem>
      <ProjectItem ReplaceParameters="true" TargetFileName="Program.cs">Program.cs</ProjectItem>
      <ProjectItem ReplaceParameters="true" TargetFileName="ViteHelper.cs">ViteHelper.cs</ProjectItem>
      <ProjectItem ReplaceParameters="true" TargetFileName="WeatherForecast.cs">WeatherForecast.cs</ProjectItem>
    </Project>
  </TemplateContent>
</VSTemplate>
```

**各後端差異**：
- **Controllers**：刪 `Pages/`，`Description` 改 `ASP.NET Core 10 (Controllers) + ...`。
- **MinimalAPI**：刪 `Pages/` 與 `Controllers/`，`Program.cs` 用 `app.MapGet(...)` 版本。
- **MVC**：保留 `Pages/` 與 `Controllers/`（如上）。

### 5.5 自動化打包（推薦）— `scripts/build-zips.ps1`

腳本一次完成 12 個 ZIP 的組裝、namespace 取代、`.vstemplate` 產生、壓縮，**無需手動 §5.1–§5.4**。

執行：
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-zips.ps1
```

腳本內部步驟（與 §5.1–§5.4 一一對應）：

1. **抽出範本圖示**：從 `ProjectTemplates/Vite_VueTS_And_Net10_Controllers.zip` 解出 `__TemplateIcon.png`（VSIX 容器內不存原始 PNG）。
2. **組裝工作資料夾**：
   - 從 `Net10_<Backend>_And_Vite/` 排除 `obj/`、`bin/`、`ClientApp/` 複製後端檔案到工作根目錄。
   - 從 `ClientApps/<frontend>/` 整包複製到工作根目錄下的 `ClientApp/`。
3. **字串取代**（一次處理 12 個 ZIP）：
   - 後端 token：`Net10_Controller_And_Vite`、`Net10_MinimalAPI_And_Vite`、`Net10_MVC_And_Vite` → `$safeprojectname$`
   - 前端 token：`react-js`、`react-ts`、`vue-js`、`vue-ts` → `$safeprojectname$`
   - 副檔名限定為文字檔（`.cs` `.cshtml` `.csproj` `.json` `.ts` `.tsx` `.js` `.jsx` `.html` `.vue` `.md` `.svg` 等），二進位不動。
4. **動態產生 `MyTemplate.vstemplate`**：掃描工作資料夾實際檔案結構，依資料夾分組輸出 `<Folder>` / `<ProjectItem>` 節點，`<ReplaceParameters>` 一律設 `true`。
5. **壓縮成 ZIP**：用 `System.IO.Compression.ZipArchive` 把工作資料夾內容壓到 ZIP 根目錄（內部路徑用 `/`）。
6. **產出位置**：`AspNetCore_Vite_Starter/AspNetCore_Vite_Starter/ProjectTemplates/Vite_*_And_Net10_*.zip`（12 個）。

腳本輸出的成功訊息範例：
```
✔ 已建立: ...\ProjectTemplates\Vite_ReactJS_And_Net10_Controllers.zip
...
=== 完成,目前 ProjectTemplates 內的 ZIP 數量 ===
12
```

### 5.6 放入範本圖示

`__TemplateIcon.png` 由 `build-zips.ps1` 自動從現有 ZIP 抽出並嵌入每個新 ZIP。這是「新增專案」對話框裡顯示的縮圖。

### 5.7 驗證 ZIP 結構

```powershell
Add-Type -AssemblyName System.IO.Compression.FileSystem
$z = [System.IO.Compression.ZipFile]::OpenRead("D:\...\ProjectTemplates\Vite_VueTS_And_Net10_MVC.zip")
$z.Entries | Select-Object FullName | Format-Table -AutoSize
$z.Dispose()
```

**檢查重點**：
1. `MyTemplate.vstemplate` 在 **ZIP 根**（不是子資料夾內）。
2. `*.csproj` 也在根。
3. `ViteHelper.cs` 內是 `namespace $safeprojectname$`（不是 `Net10_*`）。
4. 沒有殘留 `bin/`、`obj/`、`node_modules/`。

---

## 6. 同步 VSIX 宣告（兩份檔案）

> 目前（2026-06）這兩份**已宣告 12 個 `*_Net10_*.zip`**，新增/移除/改名 ZIP 時兩份都要同步。

### 6.1 `AspNetCore_Vite_Starter.csproj`

每個 ZIP 一條 `<Content Include>`（共 12 條）：
```xml
<Content Include="ProjectTemplates\Vite_VueTS_And_Net10_MVC.zip">
  <CopyToOutputDirectory>Always</CopyToOutputDirectory>
  <IncludeInVSIX>true</IncludeInVSIX>
</Content>
```

### 6.2 `source.extension.vsixmanifest`

每個 ZIP 一條 `<Asset>`（共 12 條）：
```xml
<Asset Type="Microsoft.VisualStudio.ProjectTemplate" d:Source="File"
       Path="ProjectTemplates"
       d:TargetPath="ProjectTemplates\Vite_VueTS_And_Net10_MVC.zip" />
```

> 若新增/移除/改名 ZIP，**兩份檔案都要同步**，否則 VSIX 建置會找不到檔案。

---

## 7. 建置 VSIX

VSIX 專案是 **.NET Framework 4.8 + VSSDK**，必須在 **Visual Studio 內**建置（CLI 的 `dotnet build` 不支援 VSSDK 目標）：

1. 用 VS 開啟 `AspNetCore_Vite_Starter.slnx`。
2. 組態選 **Release**。
3. 在「方案總管」對 `AspNetCore_Vite_Starter` 專案右鍵 → **建置**。
4. 產出 `.vsix` 位於 `AspNetCore_Vite_Starter\AspNetCore_Vite_Starter\bin\Release\`。

---

## 8. 驗證

### 8.1 安裝測試
雙擊產出的 `.vsix` 安裝到目前的 VS（或用實驗執行個體：`devenv /rootsuffix Exp`）。

### 8.2 建立專案測試
1. VS → 新增專案 → 搜尋 `Vite` → 應看到 12 個範本。
2. 專案名輸入**含特殊字元**的名稱（如 `My-Test App`），驗證 `$safeprojectname$` 清理成 `My_Test_App`。
3. 確認：
   - namespace 正確（`namespace My_Test_App`，不是 `Net10_*`）。
   - F5 能跑（後端 + Vite dev server + Swagger/MVC 頁面）。
4. 12 個範本逐一（或抽樣）測試。

---

## 9. 當前狀態與待辦（2026-06）

| 項目 | 狀態 | 動作 |
|---|---|---|
| 3 個 `Net10_*` 後端範例 | ✅ 已升級 .NET 10 + minimal hosting | — |
| `ClientApps/` 四個前端 | ✅ 已是新版 Vite 結構 | — |
| `scripts/build-zips.ps1` | ✅ 已建立並驗證 | 修改前後端/前端時重跑即可重打包 |
| `csproj` 的 `<Content Include>` | ✅ 已宣告 12 個 `*_Net10_*.zip` | 新增/移除 ZIP 時同步更新 |
| `vsixmanifest` 的 `<Assets>` | ✅ 已宣告 12 個 `*_Net10_*.zip` | 同上 |
| **12 個實體 ZIP** | ✅ 已打包為 .NET 10 + 4 前端 × 3 後端 全組合 | 重打包：執行 `build-zips.ps1` |
| MVC 範例本機 namespace 硬編碼 | ⚠️ 仍存在於 `Net10_MVC_And_Vite/` 的 Controllers/Pages | 不影響 F5；建議日後把本機也改用 `$safeprojectname$` |

---

## 10. 常見陷阱

1. **ZIP 根多包一層資料夾** → VS 找不到 `.vstemplate`，範本不出現。一定要把內容壓到根。
2. **改到原始 `Net10_*` 範例的 namespace** → 範例專案 F5 失效。只在工作副本上改。
3. **namespace 用 `$projectname$` 而非 `$safeprojectname$`** → 專案名含空格/連字號時編譯失敗。
4. **忘了設 `ReplaceParameters="true"`** → `$safeprojectname$` 不會被替換，檔案內容原樣保留（編譯錯誤）。
5. **把 `node_modules/` 壓進 ZIP** → ZIP 暴肥數百 MB。前端來源用 `ClientApps/`（已無 `node_modules`）。
6. **`csproj` 與 `vsixmanifest` 檔名不同步** → VSIX 建置報「找不到檔案」。改 ZIP 檔名時兩份都要改。
7. **改 `build-zips.ps1` 的 `tokensToReplace` 列表時漏字串** → 對應硬編碼的 namespace/識別碼不會被取代，回頭出包本機範例別名錯亂。
8. **`build-zips.ps1` 跑出來 vstemplate 內資料夾路徑用 `\`（如 `ClientApp\src`）** → 與原作者風格一致，VS 接受；若想強制 `/`，改 `Get-FolderMap` 的 `-replace`。
