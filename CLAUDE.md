# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 專案概述

本倉庫是 Visual Studio Extension 專案 `AspNetCore_Vite_Starter`,提供整合 ASP.NET Core 後端與 Vite 前端的專案範本(已發佈到 VS Marketplace: https://marketplace.visualstudio.com/items?itemName=MakotoAtsu.AspNetCoreViteStarter)。

目前為 **v3.0**(.NET 10):3 個 `Net10_*` 範例專案 + 12 個 VSIX 範本 ZIP(3 後端 × 4 前端全組合)皆已升級完成,並以 `scripts/build-zips.ps1` 自動化打包。

## 解決方案結構

Solution 檔為 **`.slnx`**(`AspNetCore_Vite_Starter/AspNetCore_Vite_Starter.slnx`),內含:

- **`AspNetCore_Vite_Starter/`** — VSIX 容器專案(.NET Framework 4.8 + VSSDK),本身不寫邏輯,只透過 `source.extension.vsixmanifest` 的 `<Asset>` 打包 12 個 ZIP 範本。
- **`Net10_Controller_And_Vite/`** — .NET 10 Sample,Controllers 風格,minimal hosting(`Program.cs` top-level + `app.MapControllers()`)。
- **`Net10_MinimalAPI_And_Vite/`** — .NET 10 Sample,Minimal API 風格(`app.MapGet(...)`)。
- **`Net10_MVC_And_Vite/`** — .NET 10 Sample,MVC Controllers + Razor Pages,minimal hosting。
- **`ClientApps/{react-js, react-ts, vue-js, vue-ts}/`** — **前端權威來源**(無 `node_modules`),作為打包進 ZIP 前的編輯來源。
- **`scripts/build-zips.ps1`** — 自動化打包腳本,從上述來源批次產生 12 個 ZIP。

> ⚠️ **`Net10_*` Sample 範例 = 純 zip 打包來源,不是可執行專案。**
> 三個 `Net10_*` 目錄下的 `.cs`/`.cshtml` 內 namespace **已**用 VS 範本語法 `$safeprojectname$`(MVC 的 `Controllers/WeatherForecastController.cs`、`Pages/Error.cshtml`、`Pages/Error.cshtml.cs`、`Pages/_ViewImports.cshtml` 這 4 個檔案仍 hardcode `Net10_MVC_And_Vite` — `build-zips.ps1` 在打包時會自動取代),**直接 `dotnet build`/`dotnet run` 會因 `CS1001/CS1056` 失敗**。
> 想實際跑某個範本?用 `scripts/build-zips.ps1` 產出 ZIP → 用 VS「新增專案」選該範本建立新專案 → F5。

### 12 種範本對照(VSIX ZIP,皆為 .NET 10)

| # | 範本 ZIP 檔名 | 後端 | 前端 |
|---|---|---|---|
| 1 | `Vite_ReactJS_And_Net10_Controllers.zip` | Controllers | React (JS) |
| 2 | `Vite_ReactJS_And_Net10_MinimalAPI.zip` | Minimal API | React (JS) |
| 3 | `Vite_ReactJS_And_Net10_MVC.zip` | MVC | React (JS) |
| 4 | `Vite_ReactTS_And_Net10_Controllers.zip` | Controllers | React + TS |
| 5 | `Vite_ReactTS_And_Net10_MinimalAPI.zip` | Minimal API | React + TS |
| 6 | `Vite_ReactTS_And_Net10_MVC.zip` | MVC | React + TS |
| 7 | `Vite_VueJS_And_Net10_Controllers.zip` | Controllers | Vue (JS) |
| 8 | `Vite_VueJS_And_Net10_MinimalAPI.zip` | Minimal API | Vue (JS) |
| 9 | `Vite_VueJS_And_Net10_MVC.zip` | MVC | Vue (JS) |
| 10 | `Vite_VueTS_And_Net10_Controllers.zip` | Controllers | Vue + TS |
| 11 | `Vite_VueTS_And_Net10_MinimalAPI.zip` | Minimal API | Vue + TS |
| 12 | `Vite_VueTS_And_Net10_MVC.zip` | MVC | Vue + TS |

`AspNetCore_Vite_Starter/ClientApps/{vue-js,vue-ts,react-js,react-ts}/` 是未壓縮的 Vite 前端原始碼,作為打包進 ZIP 前的編輯來源。三個 `Net10_*` Sample 各帶一份 `ClientApp/`,12 個 ZIP = 後端(3)× 前端(4)全組合。

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

- 三個專案的 `.cs`/`.cshtml` 內 namespace 一律用 VS 範本語法 `$safeprojectname$`(MVC 的 4 個 Controllers/Pages 檔案仍 hardcode `Net10_MVC_And_Vite`,由 `build-zips.ps1` 在打包時取代)。
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

### 建置 VSIX 容器專案(.slnx)

```powershell
# .slnx 內三個 Net10_* Sample 會因 $safeprojectname$ 報錯 — 屬預期,本機 Sample 不應直接 build
# 真正需求是 build VSIX 容器(需在 VS 內建置,因為 .NET Framework 4.8 + VSSDK)
```

### 重新打包 12 個範本 ZIP

```powershell
# 從 Net10_* Sample + ClientApps/<frontend>/ 自動組裝 12 個 ZIP
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-zips.ps1
```

腳本會:
1. 從三個 `Net10_*` 排除 `obj/`、`bin/`、`ClientApp/` 複製後端檔案
2. 從 `ClientApps/<frontend>/` 整包複製到 `ClientApp/`
3. 把硬編碼 token(`Net10_Controller_And_Vite`/`Net10_MinimalAPI_And_Vite`/`Net10_MVC_And_Vite`、`react-js`/`react-ts`/`vue-js`/`vue-ts`)統一取代為 `$safeprojectname$`
4. 動態產生 `MyTemplate.vstemplate`
5. 壓縮成 ZIP,內部路徑用 `/`,VSIX 範本可直接讀

### 建置/封裝 VSIX

在 Visual Studio 中以 Release 組態建置 `AspNetCore_Vite_Starter` 專案,產出位於其 `bin\Release\` 下的 `.vsix`。

### 修改範本後重新發布

1. 在對應的 `Net10_*` 範例專案修改 `ViteHelper.cs`、`Program.cs`、`.csproj` 等
2. 同步到 `ClientApps/{vue-js,vue-ts,react-js,react-ts}/` 對應目錄
3. 重跑 `scripts/build-zips.ps1` 重新壓縮
4. 用 Visual Studio 建置 `AspNetCore_Vite_Starter` Release 組態產出新 `.vsix`
5. `gh release create` 新版本並上傳 `.vsix`(更新 `<Identity Version>` 與 `manifest` 一致)

### 想 F5 測試某個範本?不要直接 build Sample 目錄

```powershell
# 1. 重新打包
.\scripts\build-zips.ps1

# 2. 在 VS「新增專案」對話框搜尋 Vite,選你要的範本
#    (範例: Vite_ReactTS_And_Net10_Controllers)
# 3. 用 VS 為新專案建立資料夾,F5 跑得動
```

## 修改時的注意事項

### ViteHelper 的設計慣例

- 預設 Vite port = 3000
- 啟動後等待 "VITE ready in"(v3)或 "Dev server running at:"(v2)字串才視為啟動成功
- PFX 密碼每次重新產生(`Guid.NewGuid().ToString("N")`),不要硬編碼

### 範本 ZIP 內容

ZIP 內的根目錄名稱會成為 VS 顯示的「專案名稱」。若更改範本資料夾結構,需重新打包並更新 `source.extension.vsixmanifest`。

詳細打包流程、Namespace 取代規則、常見陷阱見 `PACKAGING.md`。

## 不要做的事

- **不要在 `Net10_*` Sample 目錄下直接 `dotnet build` / `dotnet run`** — 會因 `$safeprojectname$` 報 `CS1001`/`CS1056` 失敗。Sample 是 zip 打包來源,不是可執行專案。
- 不要把 `node_modules/`、`bin/`、`obj/`、`*.pfx` 加進版本控管(已列在 `.gitignore`)
- 不要直接編輯 `ProjectTemplates/*.zip` 內的檔案(改完不會同步回 Sample 範例)
- 不要把三份 `ViteHelper.cs` 合併成單一程式庫(會破壞 VSIX 範本的自包含特性,每個 ZIP 必須能獨立解壓縮執行)
- 不要動 VSIX 專案的 `<TargetFrameworkVersion>v4.8</TargetFrameworkVersion>`(VSIX 擴充套件必須以 .NET Framework 為目標)
