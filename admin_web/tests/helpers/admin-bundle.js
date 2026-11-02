const { build } = require('esbuild');
const { readFile } = require('node:fs/promises');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const bundles = new Map();

// Inject test-only access before minification, so tests do not depend on emitted names/spacing.
function instrumentAdminBundle(injection, transform) {
  const cacheKey = injection + (transform ? transform.toString() : '');
  if (!bundles.has(cacheKey)) {
    bundles.set(cacheKey, build({
      entryPoints: [path.join(root, 'app.js')],
      bundle: true,
      minify: true,
      format: 'iife',
      platform: 'browser',
      target: 'es2020',
      outfile: path.join(root, 'app.bundle.js'),
      write: false,
      plugins: [{
        name: 'admin-test-access',
        setup(builder) {
          builder.onLoad({ filter: /[\\/]app\.js$/ }, async ({ path: filename }) => {
            const raw = await readFile(filename, 'utf8');
            const source = transform ? transform(raw) : raw;
            const marker = 'window.configureRoleAccess = configureRoleAccess;';
            if (!source.includes(marker)) throw new Error('Admin session test entry point was not found.');
            return { contents: source.replace(marker, `${marker}\n${injection}`), loader: 'js' };
          });
        },
      }],
    }).then(result => result.outputFiles.find(file => file.path.endsWith('.js')).text));
  }
  return bundles.get(cacheKey);
}

module.exports = { instrumentAdminBundle };
