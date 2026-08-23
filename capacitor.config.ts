import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.bingo.omn',
  appName: 'BINGO Oman',
  webDir: 'www',
  bundledWebRuntime: false,
  android: {
    allowMixedContent: false,
    backgroundColor: '#ffffff'
  },
  ios: {
    contentInset: 'automatic',
    backgroundColor: '#ffffff'
  }
};

export default config;
