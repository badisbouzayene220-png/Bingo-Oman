const { contextBridge } = require('electron');

contextBridge.exposeInMainWorld('bingoDesktop', {
  platform: process.platform,
  version: process.versions.electron
});
