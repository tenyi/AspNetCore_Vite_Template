# AspNetCore_Vite_Template
A Startup Template for ASP\.NET Core and Vite project

# Feature
1. Integrating ASP\.NET Core and Vite.
2. Support frontend app HMR
3. Support HTTPS
4. Auto build and publish frontend app when publishing backend app
5. 12 templates — 3 backends (Controllers / Minimal API / MVC) × 4 frontends (Vue / React in JS or TS)
6. **Built on .NET 10** — this version only supports .NET 10. The older .NET 6 and ASP\.NET Core MVC 5 templates have been removed.

|                                  |  Vue + TypeScript |  Vue  | React + TypeScript |  React |
| :------------------------------: | :---------------: | :---: | :----------------: | :----: |
| ASP\.NET Core MVC (.NET 10)       |        O          |   O   |         O          |    O   |
| .NET 10 Controllers              |        O          |   O   |         O          |    O   |
| .NET 10 Minimal API              |        O          |   O   |         O          |    O   |


# Credits
Special thanks to [**MakotoAtsu**](https://github.com/MakotoAtsu) for creating the original [AspNetCore Vite Starter](https://marketplace.visualstudio.com/items?itemName=MakotoAtsu.AspNetCoreViteStarter). This fork stands on the foundation they provided — thank you for the great work.


# How to use it
Download the latest `.vsix` release from [GitHub Releases](https://github.com/tenyi/AspNetCore_Vite_Template/releases) and install it in Visual Studio 2026 or newer.

<br>

1. Install the `.vsix` in Visual Studio (double-click the downloaded file, or use the VS extension manager)
<br>

2. Create a new project and choose 1 template
<br>
<img width="665" alt="image" src="https://user-images.githubusercontent.com/7738420/196026602-eb69230e-e9d8-4af9-8dc2-5fbba1f60c68.png">

4. Press F5 to run both backend and frontend server
<br>
<img width="735" alt="image" src="https://user-images.githubusercontent.com/7738420/196026878-8655d944-f020-415d-bb85-e24d7596dd86.png">
<br>
<img width="960" alt="image" src="https://user-images.githubusercontent.com/7738420/196026908-dc6a325e-25d5-45f2-aa75-078c25544980.png">
<br>

5. Hit button to fetch data from the backend
<br>
<img width="960" alt="image" src="https://user-images.githubusercontent.com/7738420/196026980-55357cf8-4d48-4e7c-ae0d-d7f455d800c9.png">
<br>
6. Frontend app will auto-build when you publish the backend app
<br>
<img width="467" alt="image" src="https://user-images.githubusercontent.com/7738420/196027380-9f0100ff-ab35-4892-975e-9a9cbd1f565b.png">
<br>
<img width="427" alt="image" src="https://user-images.githubusercontent.com/7738420/196027241-cc9d54b2-9986-4f70-b5b0-36a7125b3799.png">
<br>

# If you want to use other Vite template
Just create a new Vite template and replace all content in the ClientApp folder