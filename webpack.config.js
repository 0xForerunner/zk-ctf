import { createRequire } from 'module';
import webpack from 'webpack';
import HtmlWebpackPlugin from 'html-webpack-plugin';
import Dotenv from 'dotenv-webpack';
import NodePolyfillPlugin from 'node-polyfill-webpack-plugin';

const require = createRequire(import.meta.url);

export default (_, argv) => ({
  entry: {
    main: './app/main.ts',
  },
  target: 'web',
  devtool: 'source-map',
  module: {
    rules: [
      {
        test: /\.tsx?$/,
        loader: 'ts-loader',
        options: {
          transpileOnly: true,
          compilerOptions: {
            module: 'esnext',
            target: 'es2020',
            moduleResolution: 'node',
            allowSyntheticDefaultImports: true,
            esModuleInterop: true,
          },
        },
      },
      {
        test: /\.css$/,
        use: ['style-loader', 'css-loader'],
      },
    ],
  },
  plugins: [
    new HtmlWebpackPlugin({
      template: './app/index.html',
      scriptLoading: 'module',
    }),
    new Dotenv({ path: './.env' }),
    new webpack.ProvidePlugin({ Buffer: ['buffer', 'Buffer'] }),
    new webpack.DefinePlugin({
      'process.env.NODE_ENV': JSON.stringify(process.env.NODE_ENV || 'development'),
    }),
    new NodePolyfillPlugin({
      includeAliases: ['util', 'path', 'crypto', 'os', 'stream', 'buffer', 'events', 'url', 'querystring', 'assert', 'timers', 'vm', 'string_decoder']
    }),
  ],
  resolve: {
    extensions: ['.ts', '.js', '.json'],
    fallback: {
      async_hooks: false,
      'util/types': false,
      fs: false,
      net: false,
      tls: false,
      child_process: false,
      cluster: false,
      dgram: false,
      dns: false,
      domain: false,
      module: false,
      punycode: false,
      readline: false,
      repl: false,
      sys: false,
      v8: false,
      worker_threads: false,
      zlib: false,
      http: false,
      https: false,
    },
  },
  devServer: {
    port: 3000,
    headers: {
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp'
    },
    client: {
      overlay: false,
    },
  },
  experiments: {
    topLevelAwait: true,
  },
});
