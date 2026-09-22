import {Config} from '@remotion/cli/config';
Config.setVideoImageFormat('jpeg');
Config.setOverwriteOutput(true);
Config.setChromiumOpenGlRenderer('angle');

Config.overrideWebpackConfig(config => ({...config, resolve:{...config.resolve, alias:{...config.resolve?.alias, 'three$':require.resolve('three').replace('three.cjs','three.module.js')}}}));
