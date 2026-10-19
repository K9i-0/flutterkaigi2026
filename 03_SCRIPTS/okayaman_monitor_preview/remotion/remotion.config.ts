import {Config} from '@remotion/cli/config';

Config.setVideoImageFormat('png');
Config.setOverwriteOutput(true);
Config.setChromiumOpenGlRenderer('angle');
// Match the proven Three.js stage setup and keep exactly one ESM Three instance.
Config.overrideWebpackConfig((config) => ({
  ...config,
  resolve: {
    ...config.resolve,
    alias: {
      ...config.resolve?.alias,
      'three$': require.resolve('three').replace('three.cjs', 'three.module.js'),
    },
  },
}));
