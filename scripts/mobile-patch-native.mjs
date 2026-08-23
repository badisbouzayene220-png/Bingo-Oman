import fs from 'node:fs';

const target = process.argv[2];
if(target==='android'){
  const p='android/app/src/main/AndroidManifest.xml';
  let s=fs.readFileSync(p,'utf8');
  const perms=[
    '    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />',
    '    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />',
    '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />'
  ];
  for(const perm of perms){
    if(!s.includes(perm)) s=s.replace('    <uses-permission android:name="android.permission.INTERNET" />','    <uses-permission android:name="android.permission.INTERNET" />\n'+perm);
  }
  fs.writeFileSync(p,s);
  console.log('Android location + notification permissions patched.');
}else if(target==='ios'){
  const p='ios/App/App/Info.plist';
  let s=fs.readFileSync(p,'utf8');
  const block='\n\t<key>NSLocationWhenInUseUsageDescription</key>\n\t<string>BINGO Oman uses your location to show nearby listings and track deliveries.</string>\n\t<key>NSCameraUsageDescription</key>\n\t<string>BINGO Oman uses the camera so you can add photos to listings.</string>\n\t<key>NSPhotoLibraryUsageDescription</key>\n\t<string>BINGO Oman uses your photo library so you can upload listing and profile images.</string>\n';
  if(!s.includes('NSLocationWhenInUseUsageDescription')) s=s.replace('</dict>\n</plist>',block+'</dict>\n</plist>');
  fs.writeFileSync(p,s);
  console.log('iOS privacy usage descriptions patched. Push capability must be enabled with the Apple Developer profile.');
}else{
  throw new Error('Use android or ios');
}
