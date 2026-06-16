# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 專案概述

本倉庫是 Visual Studio Extension 專案 `AspNetCore_Vite_Starter`,提供整合 ASP.NET Core 後端與 Vite 前端的專案範本(已發佈到 VS Marketplace: https://marketplace.visualstudio.com/items?itemName=MakotoAtsu.AspNetCoreViteStarter)。

目前正處於 **.NET 5/6 → .NET 10 升級** 過渡期:倉庫內的 3 個**範例專案已升級到 .NET 10 並改名為 `Net10_*`**,但 VSIX 打包用的 9 個 ZIP 範本**仍是舊的 .NET 5/6 版本,尚未重打包**(見下方「待辦:VSIX ZIP 重打包」)。

## 解決方案結構

Solution 檔已從 `.sln` 改為 **`.slnx`**(`AspNetCore_Vite_Starter/AspNetCore_Vite_Starter.slnx`),內含:

- **`AspNetCore_Vite_Starter/`** — VSIX 容器專案(.NET Framework 4.8 + VSSDK),本身不寫邏輯,只透過 `source.extension.vsixmanifest` 的 `<Asset>` 打包 9 個 ZIP 範本。
- **`Net10_Controller_And_Vite/`** — .NET 10 範例,Controllers 風格,minimal hosting(`Program.cs` top-level + `app.MapControllers()`)。
- **`Net10_MinimalAPI_And_Vite/`** — .NET 10 範例,Minimal API 風格(`app.MapGet(...)`)。
- **`Net10_MVC_And_Vite/`** — .NET 10 範例,MVC Controllers + Razor Pages,已從舊 `Startup.cs` 改寫為 minimal hosting。

`AspNetCore_Vite_Starter/ClientApps/`(vue-js, vue-ts, react-js, react-ts)是**未壓縮的 Vite 前端原始碼**,作為打包進 ZIP 前的編輯來源。

> 三個 `Net10_*` 範例專案各自帶一份 `ClientApp/`(前端),組合 = 後端風格(3 種)× 前端(Vue/React × JS/TS)。VSIX 的 9 個 ZIP 即這些組合的打包產物。

### 9 種範本對照(VSIX ZIP,**目前仍是 .NET 5/6,待重打包**)

| 範本 ZIP 檔名 | 後端 | 前端 |
|---|---|---|
| `Vite_ReactJS_And_Net6_Controllers.zip` | Controllers | React (JS) |
| `Vite_ReactJS_And_Net6_MinimalAPI.zip` | Minimal API | React (JS) |
| `Vite_ReactTS_And_Net6_Controllers.zip` | Controllers | React + TS |
| `Vite_ReactTS_And_Net6_MinimalAPI.zip` | Minimal API | React + TS |
| `Vite_VueJS_And_Net6_Controllers.zip` | Controllers | Vue (JS) |
| `Vite_VueJS_And_Net6_MinimalAPI.zip` | Minimal API | Vue (JS) |
| `Vite_VueTS_And_Net5_MVC.zip` | MVC | Vue + TS |
| `Vite_VueTS_And_Net6_Controllers.zip` | Controllers | Vue + TS |
| `Vite_VueTS_And_Net6_MinimalAPI.zip` | Minimal API | Vue + TS |

## 核心架構

### `ViteHelper.UseViteDevelopmentServer()`

每個 `Net10_*` 專案都有一份 `ViteHelper.cs`(內容近乎相同,刻意不共用),這是 ASP.NET Core 與 Vite 整合的核心。流程為:

1. 檢查 Node.js 是否安裝(`node --version`)
2. 確認 3000 port 未被佔用 → 啟動 Vite 開發伺服器
3. 透過 `dotnet dev-certs https` 匯出 PFX 憑證到 `ClientApp/devcert.pfx`
4. 產生 `serverOption.{js,ts}` 並**注入**到 `vite.config`(`InjectionViteConfig` 會在現有 `export default` 後插入 `server: serverOption,`)
5. 若 `node_modules` 不存在則跑 `npm install`
6. 啟動 `npm run dev -- --port {port}` 並等待 "VITE ready in" / "Dev server running at:" 字串
7. 透過 `spa.UseProxyToSpaDevelopmentServer` 反向代理到 `https://localhost:3000`

### .NET 10 / minimal hosting 慣例(三個專案已統一)

- 三個專案的 namespace 已與資料夾/專案名對齊:`Net10_Controller_And_Vite`、`Net10_MinimalAPI_And_Vite`、`Net10_MVC_And_Vite`(MVC 的 `Pages/_ViewImports.cshtml` 用 `@namespace Net10_MVC_And_Vite.Pages`)。
- `Program.cs` 皆為 top-level statements,**不再用** `Startup.cs`/`UseRouting()`/`UseEndpoints()` 包裹(minimal hosting 自動處理 ordering)。
- `<Nullable>enable</Nullable>` + `<ImplicitUsings>enable</ImplicitUsings>` 三個專案都已開啟。
- Swagger/OpenAPI:三個專案統一用 `Swashbuckle.AspNetCore`(`AddSwaggerGen` + `UseSwagger/UseSwaggerUI`,僅 Dev 環境),保留開箱即用的 Swagger UI。

### MSBuild 自動建置流程

每個範本 `*.csproj` 內含三個關鍵 `<Target>`:

- **`DebugEnsureNodeEnv`** (Build 前,僅 Debug):缺少 `node_modules` 時跑 `npm install`
- **`BuildVue`** (Build 前,僅 Release):跑 `npm run build`
- **`PublishRunVite`** (在 `ComputeFilesToPublish` 之後):發佈時跑 `npm install` + `npm run build`,把 `ClientApp/dist/**` 與(SSR 模式下)`node_modules/**` 收進發佈產出

### SPA 服務註冊

- `builder.Services.AddSpaStaticFiles(...)` — 設定 `RootPath = "ClientApp/dist"`,給 production 用
- `app.UseSpa(spa => spa.UseViteDevelopmentServer(sourcePath: "ClientApp"))` — 開發時期接管,必須排在所有 `MapControllers`/`MapGet` 之後(是最後的 fallback)

## 開發命令

環境需求:Windows + Visual Studio 2022 + Node.js + **.NET 10 SDK**。

### 建置範例專案

```powershell
# 透過 .slnx 建置三個 Net10_* 範例(VSIX 專案為 .NET Framework + VSSDK,需在 VS 內建置)
dotnet build .\AspNetCore_Vite_Starter\AspNetCore_Vite_Starter.slnx
```

### 執行範例專案(F5 除錯)

```powershell
dotnet run --project .\AspNetCore_Vite_Starter\Net10_Controller_And_Vite
# 首次執行會自動:檢查 node/npm → 匯出 devcert.pfx → 注入 vite.config → npm install → 啟動 Vite dev server
```

### 建置/封裝 VSIX

在 Visual Studio 中以 Release 組態建置 `AspNetCore_Vite_Starter` 專案,產出位於其 `bin\Release\` 下的 `.vsix`。

### 修改範本後重新打包 ZIP

1. 在對應的 `Net10_*` 範例專案修改 `ViteHelper.cs`、`Program.cs`、`.csproj` 等
2. 同步到 `ClientApps/{vue-js,vue-ts,react-js,react-ts}/` 對應目錄
3. 將修改後的範例專案重新壓縮成 `AspNetCore_Vite_Starter/ProjectTemplates/*.zip`
4. 確認 `AspNetCore_Vite_Starter.csproj` 內 `<Content Include="ProjectTemplates\...">` 與 `source.extension.vsixmanifest` 的 `<Assets>` 有對應條目

## 修改時的注意事項

### ViteHelper 的設計慣例

- 預設 Vite port = 3000
- 啟動後等待 "VITE ready in"(v3)或 "Dev server running at:"(v2)字串才視為啟動成功
- PFX 密碼每次重新產生(`Guid.NewGuid().ToString("N")`),不要硬編碼

### 待辦:VSIX ZIP 重打包

VSIX 的 9 個 ZIP、`AspNetCore_Vite_Starter.csproj` 的 `<Content Include>`、`source.extension.vsixmanifest` 的 `<Assets>` 目前仍指向 `.NET 5/6` 版的範本檔名(`Vite_*_Net5_*.zip` / `Vite_*_Net6_*.zip`)。要完成 .NET 10 升級,需把 3 個 `Net10_*` 範例重新打包成對應 ZIP 並更新這兩處宣告(檔名也建議改成 `*_Net10_*`)。這是獨立任務,不屬於「C#/.csproj 現代化」。

### 範本 ZIP 內容

ZIP 內的根目錄名稱會成為 VS 顯示的「專案名稱」。若更改範本資料夾結構,需重新打包並更新 `source.extension.vsixmanifest`。

## 不要做的事

- 不要把 `node_modules/`、`bin/`、`obj/`、`*.pfx` 加進版本控管(已列在 `.gitignore`)
- 不要直接編輯 `ProjectTemplates/*.zip` 內的檔案(改完不會同步回原始範例專案)
- 不要把三份 `ViteHelper.cs` 合併成單一程式庫(會破壞 VSIX 範本的自包含特性,每個 ZIP 必須能獨立解壓縮執行)
- 不要動 VSIX 專案的 `<TargetFrameworkVersion>v4.8</TargetFrameworkVersion>`(VSIX 擴充套件必須以 .NET Framework 為目標)
