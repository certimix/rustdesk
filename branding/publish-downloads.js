import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '..');
const downloadsDir = path.join(rootDir, 'web', 'public', 'downloads');

if (!fs.existsSync(downloadsDir)) {
  fs.mkdirSync(downloadsDir, { recursive: true });
}

console.log('=================================================================');
console.log(' Publicador de Instaladores ZenyDesk Client para /downloads/');
console.log('=================================================================');

const targets = [
  {
    name: 'Windows (.exe)',
    searchPaths: [
      path.join(rootDir, 'target', 'release', 'zenydesk.exe'),
      path.join(rootDir, 'target', 'release', 'Zenydesk-Client-Setup-x64.exe'),
      path.join(rootDir, 'res', 'inno', 'Output', 'Zenydesk-Client-Setup-x64.exe')
    ],
    destName: 'Zenydesk-Client-Setup-x64.exe'
  },
  {
    name: 'macOS (.dmg)',
    searchPaths: [
      path.join(rootDir, 'target', 'release', 'bundle', 'osx', 'Zenydesk.dmg'),
      path.join(rootDir, 'target', 'release', 'Zenydesk-Client-v1.3.2.dmg')
    ],
    destName: 'Zenydesk-Client-v1.3.2.dmg'
  },
  {
    name: 'Linux (.AppImage)',
    searchPaths: [
      path.join(rootDir, 'target', 'release', 'zenydesk.AppImage'),
      path.join(rootDir, 'target', 'release', 'Zenydesk-Client-v1.3.2-x86_64.AppImage')
    ],
    destName: 'Zenydesk-Client-v1.3.2-x86_64.AppImage'
  },
  {
    name: 'Android (.apk)',
    searchPaths: [
      path.join(rootDir, 'flutter', 'build', 'app', 'outputs', 'flutter-apk', 'app-release.apk'),
      path.join(rootDir, 'target', 'release', 'Zenydesk-Client-v1.3.2.apk')
    ],
    destName: 'Zenydesk-Client-v1.3.2.apk'
  }
];

let updatedCount = 0;

targets.forEach((target) => {
  const destPath = path.join(downloadsDir, target.destName);
  let found = false;

  for (const srcPath of target.searchPaths) {
    if (fs.existsSync(srcPath)) {
      fs.copyFileSync(srcPath, destPath);
      const stat = fs.statSync(destPath);
      console.log(`[SUCESSO] ${target.name} publicado: ${target.destName} (${(stat.size / 1024 / 1024).toFixed(2)} MB)`);
      found = true;
      updatedCount++;
      break;
    }
  }

  if (!found) {
    if (fs.existsSync(destPath)) {
      const stat = fs.statSync(destPath);
      console.log(`[PRONTO] ${target.name} ativo na pasta de downloads (${(stat.size / 1024 / 1024).toFixed(2)} MB)`);
    } else {
      console.log(`[AGUARDANDO BUILD] ${target.name} ainda não foi compilado em target/release/`);
    }
  }
});

console.log('-----------------------------------------------------------------');
console.log(`Todos os instaladores do ZenyDesk Client estão sincronizados em: ${downloadsDir}`);
console.log('=================================================================');
