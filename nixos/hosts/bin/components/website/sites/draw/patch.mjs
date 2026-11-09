import { readFileSync, writeFileSync, readdirSync, rmSync } from "node:fs";

const [root, cssFile, title] = process.argv.slice(2);

function patch(file, edits) {
  let text = readFileSync(file, "utf8");
  for (const [from, to, count = 1] of edits) {
    const found = text.split(from).length - 1;
    if (found !== count) {
      throw new Error(`${file}: expected ${count} match(es) for ${JSON.stringify(from.slice(0, 80))}, found ${found}`);
    }
    text = text.split(from).join(to);
  }
  writeFileSync(file, text);
}

const app = readdirSync(`${root}/assets`).find((f) => /^index-.*\.js$/.test(f) && readFileSync(`${root}/assets/${f}`, "utf8").includes("utm_content=hamburger"));
if (!app) throw new Error("app bundle not found");

patch(`${root}/assets/${app}`, [
  [
    'g(Rt.Separator,{}),g(Rt.ItemLink,{icon:A_,href:"https://plus.excalidraw.com/plus?utm_source=excalidraw&utm_medium=app&utm_content=hamburger",className:"",children:"Excalidraw+"}),g(Rt.DefaultItems.Socials,{}),g(Rt.ItemLink,{icon:mX,href:`https://app.excalidraw.com${af?"":"/sign-up"}?utm_source=signin&utm_medium=app&utm_content=hamburger`,className:"highlighted",children:af?"Sign in":"Sign up"}),',
    "",
  ],
  [
    '!af&&g(Er.Center.MenuItemLink,{href:"https://plus.excalidraw.com/plus?utm_source=excalidraw&utm_medium=app&utm_content=welcomeScreenGuest"',
    '!1&&g(Er.Center.MenuItemLink,{href:"https://plus.excalidraw.com/plus?utm_source=excalidraw&utm_medium=app&utm_content=welcomeScreenGuest"',
  ],
  [
    'e&&g(_u.Action,{title:M("overwriteConfirm.action.excalidrawPlus.title")',
    '!1&&g(_u.Action,{title:M("overwriteConfirm.action.excalidrawPlus.title")',
  ],
  ["category:bt.links,predicate:!0", "category:bt.links,predicate:!1", 6],
  ['async function d(){if("serviceWorker"in navigator){', 'async function d(){if(!1){'],
  ["aiEnabled:W!==!1,showDeprecatedFonts", "aiEnabled:!1,showDeprecatedFonts"],
  ['VITE_APP_BACKEND_V2_GET_URL:"https://json.excalidraw.com/api/v2/"', 'VITE_APP_BACKEND_V2_GET_URL:"/api/v2/"'],
  ['VITE_APP_BACKEND_V2_POST_URL:"https://json.excalidraw.com/api/v2/post/"', 'VITE_APP_BACKEND_V2_POST_URL:"/api/v2/post/"'],
  ['children:["__fallback"in t&&t.__fallback?g("p",{className:"dialog-mermaid-title"', 'children:[!0?g("p",{className:"dialog-mermaid-title"'],
  ['mermaidToExcalidraw:"Mermaid to Excalidraw"', 'mermaidToExcalidraw:"Mermaid"'],
  ['title:"Mermaid to Excalidraw"', 'title:"Mermaid"'],
  ['excalidrawLib:"Excalidraw Library"', 'excalidrawLib:"Library"'],
  ['installPWA:"Install Excalidraw locally (PWA)"', 'installPWA:"Install locally (PWA)"'],
  ['shareTitle:"Join a live collaboration session on Excalidraw"', 'shareTitle:"Join a live collaboration session"'],
  ["which means that Excalidraw server and third parties", "which means that the server and third parties"],
  ["end-to-end encrypted so Excalidraw's servers will never see them", "end-to-end encrypted so the servers will never see them"],
  ["doesn't contain valid Excalidraw JSON data", "doesn't contain valid drawing data"],
  ['description:"Excalidraw file"', 'description:"Drawing file"'],
  ['description:"Excalidraw files"', 'description:"Drawing files"'],
  ['description:"Excalidraw library file"', 'description:"Library file"'],
  ['description:"Excalidraw library files"', 'description:"Library files"'],
]);

function strip(file, patterns) {
  let text = readFileSync(file, "utf8");
  for (const re of patterns) {
    if (!re.test(text)) throw new Error(`${file}: nothing matched ${re}`);
    text = text.replace(new RegExp(re.source, re.flags.includes("g") ? re.flags : re.flags + "g"), "");
  }
  writeFileSync(file, text);
}

strip(`${root}/index.html`, [
  /<meta (name|property)="(title|description|image|og:[a-z:_]+|twitter:[a-z:_]+)" content="[^"]*"\/>/,
  /<link rel="canonical" href="[^"]*"\/>/,
  /<script>\/\/ Redirect Excalidraw\+ users[\s\S]*?<\/script>/,
  /<script>\/\/ need to load this script dynamically bcs\. of iframe embed tracking[\s\S]*?<\/script>/,
]);

const cdn = "https://excalidraw.nyc3.cdn.digitaloceanspaces.com/oss/";
const appCss = readdirSync(`${root}/assets`).find((f) => /^index-.*\.css$/.test(f));
patch(`${root}/index.html`, [[cdn, "/", 5]]);
patch(`${root}/assets/${appCss}`, [[cdn, "/", 4]]);

const css = readFileSync(cssFile, "utf8");
patch(`${root}/index.html`, [
  ["<title>Excalidraw Whiteboard</title>", `<title>${title}</title>`],
  ['<h1 class="visually-hidden">Excalidraw</h1>', `<h1 class="visually-hidden">${title}</h1>`],
  ['<link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png"/>', ""],
  ['<link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png"/>', '<link rel="icon" type="image/svg+xml" href="/favicon.svg"/>'],
  ['<link rel="icon" type="image/png" sizes="16x16" href="/favicon-16x16.png"/>', ""],
  ['<meta name="theme-color" content="#121212"/>', '<meta name="theme-color" content="#f2b8e2"/>'],
  ["</head>", `<style>${css}</style></head>`],
]);

patch(`${root}/manifest.webmanifest`, [
  ['"name":"Excalidraw"', `"name":"${title}"`],
  ['"short_name":"Excalidraw"', `"short_name":"${title}"`],
]);

for (const f of readdirSync(`${root}/assets`)) {
  if (f.endsWith(".map")) rmSync(`${root}/assets/${f}`);
}
