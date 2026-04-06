#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const repoRoot = path.resolve(__dirname, '..');
const outputDir = path.join(repoRoot, 'docs');
const jsonOutputPath = path.join(outputDir, 'codebase-graph.json');
const markdownOutputPath = path.join(outputDir, 'codebase-graph.md');

const WORKSPACES = [
  {
    key: 'backend',
    label: 'gymmate_backend',
    root: 'gymmate_backend',
    entrypoints: ['gymmate_backend/index.js', 'gymmate_backend/app.js'],
    includeExtensions: new Set(['.js', '.json']),
    ignoreDirs: new Set(['node_modules', '.vercel', 'public', 'gymmate_admin']),
  },
  {
    key: 'admin',
    label: 'gymmate_admin_vite',
    root: 'gymmate_admin_vite/src',
    entrypoints: [
      'gymmate_admin_vite/src/main.js',
      'gymmate_admin_vite/src/router/index.js',
    ],
    includeExtensions: new Set(['.js', '.vue', '.css']),
    ignoreDirs: new Set(['node_modules', 'dist']),
  },
  {
    key: 'mobile',
    label: 'gymmate_mobile',
    root: 'gymmate_mobile/lib',
    entrypoints: ['gymmate_mobile/lib/main.dart'],
    includeExtensions: new Set(['.dart']),
    ignoreDirs: new Set(['forks']),
  },
];

function readText(filePath) {
  return fs.readFileSync(filePath, 'utf8');
}

function ensureDir(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

function walkFiles(relativeRoot, includeExtensions, ignoreDirs) {
  const absoluteRoot = path.join(repoRoot, relativeRoot);
  const results = [];

  function visit(currentDir) {
    for (const entry of fs.readdirSync(currentDir, { withFileTypes: true })) {
      if (entry.name.startsWith('.git')) {
        continue;
      }
      if (ignoreDirs.has(entry.name)) {
        continue;
      }

      const absolutePath = path.join(currentDir, entry.name);
      if (entry.isDirectory()) {
        visit(absolutePath);
        continue;
      }

      if (!includeExtensions.has(path.extname(entry.name))) {
        continue;
      }

      results.push(path.relative(repoRoot, absolutePath));
    }
  }

  if (fs.existsSync(absoluteRoot)) {
    visit(absoluteRoot);
  }

  return results.sort();
}

function listTopLevelTree(relativeDir, maxDepth = 2) {
  const absoluteDir = path.join(repoRoot, relativeDir);
  if (!fs.existsSync(absoluteDir)) {
    return [];
  }

  const lines = [];

  function visit(currentDir, depth, prefix) {
    if (depth > maxDepth) {
      return;
    }

    const entries = fs
      .readdirSync(currentDir, { withFileTypes: true })
      .filter((entry) => {
        if (entry.name.startsWith('.')) {
          return false;
        }
        return !['node_modules', 'build', 'dist', '.dart_tool'].includes(entry.name);
      })
      .sort((a, b) => a.name.localeCompare(b.name));

    entries.forEach((entry, index) => {
      const connector = index === entries.length - 1 ? '└── ' : '├── ';
      lines.push(`${prefix}${connector}${entry.name}`);

      if (entry.isDirectory() && depth < maxDepth) {
        const childPrefix = prefix + (index === entries.length - 1 ? '    ' : '│   ');
        visit(path.join(currentDir, entry.name), depth + 1, childPrefix);
      }
    });
  }

  lines.push(relativeDir);
  visit(absoluteDir, 1, '');
  return lines;
}

function normalizeJsLikeImport(fromFile, specifier) {
  if (!specifier) {
    return null;
  }
  if (specifier.startsWith('.')) {
    const baseDir = path.dirname(path.join(repoRoot, fromFile));
    const candidateBase = path.normalize(path.join(baseDir, specifier));
    const candidates = [
      candidateBase,
      `${candidateBase}.js`,
      `${candidateBase}.vue`,
      `${candidateBase}.json`,
      path.join(candidateBase, 'index.js'),
      path.join(candidateBase, 'index.vue'),
    ];
    for (const candidate of candidates) {
      if (fs.existsSync(candidate)) {
        return path.relative(repoRoot, candidate);
      }
    }
    return path.relative(repoRoot, candidateBase);
  }

  if (specifier.startsWith('package:gymmate_mobile/')) {
    return specifier.replace('package:gymmate_mobile/', 'gymmate_mobile/lib/');
  }

  return null;
}

function normalizeDartImport(fromFile, specifier) {
  if (!specifier) {
    return null;
  }
  if (specifier.startsWith('package:gymmate_mobile/')) {
    return specifier.replace('package:gymmate_mobile/', 'gymmate_mobile/lib/');
  }
  if (specifier.startsWith('.')) {
    const baseDir = path.dirname(path.join(repoRoot, fromFile));
    return path.relative(repoRoot, path.normalize(path.join(baseDir, specifier)));
  }
  return null;
}

function extractJsLikeDependencies(filePath) {
  const source = readText(path.join(repoRoot, filePath));
  const scriptSource =
    path.extname(filePath) === '.vue'
      ? Array.from(source.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/g))
          .map((match) => match[1])
          .join('\n')
      : source;

  const imports = new Set();
  const externalImports = new Set();

  const importPatterns = [
    /import\s+(?:[^'"]+?\s+from\s+)?["']([^"']+)["']/g,
    /require\(\s*["']([^"']+)["']\s*\)/g,
  ];

  for (const pattern of importPatterns) {
    let match;
    while ((match = pattern.exec(scriptSource)) !== null) {
      const specifier = match[1];
      const normalized = normalizeJsLikeImport(filePath, specifier);
      if (normalized) {
        imports.add(normalized);
      } else {
        externalImports.add(specifier);
      }
    }
  }

  return {
    internal: Array.from(imports).sort(),
    external: Array.from(externalImports).sort(),
  };
}

function extractDartDependencies(filePath) {
  const source = readText(path.join(repoRoot, filePath));
  const imports = new Set();
  const externalImports = new Set();

  let match;
  const pattern = /import\s+['"]([^'"]+)['"]\s*;/g;
  while ((match = pattern.exec(source)) !== null) {
    const specifier = match[1];
    const normalized = normalizeDartImport(filePath, specifier);
    if (normalized) {
      imports.add(normalized);
    } else {
      externalImports.add(specifier);
    }
  }

  return {
    internal: Array.from(imports).sort(),
    external: Array.from(externalImports).sort(),
  };
}

function buildWorkspaceGraph(workspace) {
  const files = walkFiles(
    workspace.root,
    workspace.includeExtensions,
    workspace.ignoreDirs,
  );
  const nodes = [];
  const edges = [];
  const externalModules = new Set();

  for (const file of files) {
    const dependencyInfo =
      path.extname(file) === '.dart'
        ? extractDartDependencies(file)
        : extractJsLikeDependencies(file);

    nodes.push({
      path: file,
      imports: dependencyInfo.internal,
      externalImports: dependencyInfo.external,
    });

    dependencyInfo.internal.forEach((target) => {
      edges.push({ from: file, to: target });
    });
    dependencyInfo.external.forEach((target) => externalModules.add(target));
  }

  const entrypointDependencies = {};
  workspace.entrypoints.forEach((entrypoint) => {
    const node = nodes.find((item) => item.path === entrypoint);
    entrypointDependencies[entrypoint] = node ? node.imports : [];
  });

  return {
    key: workspace.key,
    label: workspace.label,
    root: workspace.root,
    entrypoints: workspace.entrypoints,
    entrypointDependencies,
    fileCount: nodes.length,
    nodeSample: nodes.slice(0, 200),
    edgeCount: edges.length,
    externalModules: Array.from(externalModules).sort(),
    tree: listTopLevelTree(workspace.root),
  };
}

function extractBackendRouteSummary() {
  const appPath = path.join(repoRoot, 'gymmate_backend/app.js');
  if (!fs.existsSync(appPath)) {
    return [];
  }

  const source = readText(appPath);
  const requireMap = new Map();
  let match;

  const requirePattern = /const\s+(\w+)\s*=\s*require\(['"](.+?)['"]\);/g;
  while ((match = requirePattern.exec(source)) !== null) {
    requireMap.set(match[1], match[2]);
  }

  const mounts = [];
  const mountPattern = /app\.use\(\s*['"]([^'"]+)['"]\s*,\s*(\w+)\s*\);/g;
  while ((match = mountPattern.exec(source)) !== null) {
    const mountPath = match[1];
    const variableName = match[2];
    const routeSpecifier = requireMap.get(variableName);
    if (!routeSpecifier) {
      continue;
    }
    const routeFile = normalizeJsLikeImport('gymmate_backend/app.js', routeSpecifier);
    mounts.push({
      mountPath,
      routeFile,
      handlers: routeFile ? extractExpressHandlers(routeFile) : [],
    });
  }

  return mounts;
}

function extractExpressHandlers(routeFile) {
  const absolutePath = path.join(repoRoot, routeFile);
  if (!fs.existsSync(absolutePath)) {
    return [];
  }

  const source = readText(absolutePath);
  const controllerMap = new Map();
  let match;

  const destructuredPattern =
    /const\s*\{\s*([^}]+)\}\s*=\s*require\(['"](.+?)['"]\);/g;
  while ((match = destructuredPattern.exec(source)) !== null) {
    const names = match[1]
      .split(',')
      .map((item) => item.trim())
      .filter(Boolean);
    const target = normalizeJsLikeImport(routeFile, match[2]);
    names.forEach((name) => controllerMap.set(name, target));
  }

  const defaultPattern = /const\s+(\w+)\s*=\s*require\(['"](.+?)['"]\);/g;
  while ((match = defaultPattern.exec(source)) !== null) {
    controllerMap.set(match[1], normalizeJsLikeImport(routeFile, match[2]));
  }

  const handlers = [];
  const routePattern =
    /router\.(get|post|put|patch|delete)\(\s*['"]([^'"]+)['"]\s*,([\s\S]*?)\);/g;
  while ((match = routePattern.exec(source)) !== null) {
    const method = match[1].toUpperCase();
    const routePath = match[2];
    const handlerSource = match[3].replace(/\s+/g, ' ').trim();
    const referenced = Array.from(handlerSource.matchAll(/(\w+)\.(\w+)/g)).map(
      (item) => ({
        controllerAlias: item[1],
        action: item[2],
        file: controllerMap.get(item[1]) || null,
      }),
    );

    handlers.push({
      method,
      path: routePath,
      rawHandler: handlerSource,
      referencedControllers: referenced,
    });
  }

  return handlers;
}

function extractAdminRouteSummary() {
  const routerFile = path.join(repoRoot, 'gymmate_admin_vite/src/router/index.js');
  if (!fs.existsSync(routerFile)) {
    return [];
  }

  const source = readText(routerFile);
  const routes = [];
  const routePattern =
    /path:\s*["']([^"']+)["'][\s\S]*?name:\s*["']([^"']+)["'][\s\S]*?component:\s*\(\)\s*=>\s*import\(["']([^"']+)["']\)/g;

  let match;
  while ((match = routePattern.exec(source)) !== null) {
    routes.push({
      path: match[1],
      name: match[2],
      component: normalizeJsLikeImport('gymmate_admin_vite/src/router/index.js', match[3]),
    });
  }

  return routes;
}

function extractMobileRouteSummary() {
  const mainFile = path.join(repoRoot, 'gymmate_mobile/lib/main.dart');
  if (!fs.existsSync(mainFile)) {
    return [];
  }

  const source = readText(mainFile);
  const summaries = [];

  const routesBlockMatch = source.match(/routes:\s*\{([\s\S]*?)\}/m);
  if (routesBlockMatch) {
    const routePattern = /['"]([^'"]+)['"]\s*:\s*\(context\)\s*=>\s*const\s+(\w+)/g;
    let match;
    while ((match = routePattern.exec(routesBlockMatch[1])) !== null) {
      summaries.push({
        route: match[1],
        widget: match[2],
      });
    }
  }

  const authGateTargets = [];
  const authGateClassMatch = source.match(
    /class\s+_AuthGateState[\s\S]*?Widget\s+build\(BuildContext context\)\s*\{([\s\S]*?)\n  \}\n\}/,
  );
  if (authGateClassMatch) {
    const returnPattern = /return\s+(?:const\s+)?(\w+)\(/g;
    let match;
    while ((match = returnPattern.exec(authGateClassMatch[1])) !== null) {
      authGateTargets.push(match[1]);
    }
  }

  return {
    namedRoutes: summaries,
    authGateTargets: Array.from(new Set(authGateTargets)).sort(),
  };
}

function buildMermaid(workspaces, backendRoutes, adminRoutes, mobileRoutes) {
  const lines = ['graph TD'];
  lines.push('  Repo["gymmate-complete / codex-mvp-figma"]');
  lines.push('  Repo --> Backend["Backend API"]');
  lines.push('  Repo --> Admin["Admin Web"]');
  lines.push('  Repo --> Mobile["Mobile App"]');

  backendRoutes.forEach((mount) => {
    const routeNode = sanitizeNodeId(`backend-${mount.mountPath}`);
    lines.push(`  Backend --> ${routeNode}["${mount.mountPath}"]`);
  });

  adminRoutes.forEach((route) => {
    const routeNode = sanitizeNodeId(`admin-${route.name}`);
    lines.push(`  Admin --> ${routeNode}["${route.name}: ${route.path}"]`);
  });

  mobileRoutes.authGateTargets.forEach((target) => {
    const routeNode = sanitizeNodeId(`mobile-${target}`);
    lines.push(`  Mobile --> ${routeNode}["${target}"]`);
  });

  lines.push('  Admin --> Backend');
  lines.push('  Mobile --> Backend');
  return lines.join('\n');
}

function sanitizeNodeId(value) {
  return value.replace(/[^A-Za-z0-9_]/g, '_');
}

function toMarkdown(graph) {
  const { repo, workspaces, backendRoutes, adminRoutes, mobileRoutes, generatedAt } =
    graph;

  const lines = [];
  lines.push('# Codebase Graph');
  lines.push('');
  lines.push(`Generated: ${generatedAt}`);
  lines.push('');
  lines.push(`Branch: \`${repo.branch}\``);
  lines.push('');
  lines.push(`Remote: \`${repo.remote}\``);
  lines.push('');
  lines.push('## Purpose');
  lines.push('');
  lines.push(
    'This snapshot is a reusable architecture map for future change requests. It is intentionally compact so an agent can orient on the repo without re-reading every source file.',
  );
  lines.push('');
  lines.push('## Workspace Summary');
  lines.push('');
  workspaces.forEach((workspace) => {
    lines.push(
      `- \`${workspace.label}\`: ${workspace.fileCount} scanned files, ${workspace.edgeCount} internal dependency edges`,
    );
  });
  lines.push('');
  lines.push('## System Graph');
  lines.push('');
  lines.push('```mermaid');
  lines.push(graph.mermaid);
  lines.push('```');
  lines.push('');
  lines.push('## Backend API Mounts');
  lines.push('');
  backendRoutes.forEach((mount) => {
    lines.push(`### ${mount.mountPath}`);
    lines.push('');
    lines.push(`- Route file: \`${mount.routeFile}\``);
    mount.handlers.slice(0, 12).forEach((handler) => {
      const controllerRefs = handler.referencedControllers
        .map((item) =>
          item.file ? `${item.file}#${item.action}` : `${item.controllerAlias}.${item.action}`,
        )
        .join(', ');
      lines.push(
        `- \`${handler.method} ${handler.path}\` -> ${controllerRefs || handler.rawHandler}`,
      );
    });
    lines.push('');
  });
  lines.push('## Admin Routes');
  lines.push('');
  adminRoutes.forEach((route) => {
    lines.push(`- \`${route.path}\` -> \`${route.component}\` (${route.name})`);
  });
  lines.push('');
  lines.push('## Mobile Navigation Anchors');
  lines.push('');
  mobileRoutes.namedRoutes.forEach((route) => {
    lines.push(`- Named route \`${route.route}\` -> \`${route.widget}\``);
  });
  if (mobileRoutes.authGateTargets.length) {
    lines.push(
      `- Auth gate targets: ${mobileRoutes.authGateTargets.map((item) => `\`${item}\``).join(', ')}`,
    );
  }
  lines.push('');
  lines.push('## Trees');
  lines.push('');
  workspaces.forEach((workspace) => {
    lines.push(`### ${workspace.label}`);
    lines.push('');
    lines.push('```text');
    workspace.tree.forEach((line) => lines.push(line));
    lines.push('```');
    lines.push('');
  });
  lines.push('## Entrypoint Dependencies');
  lines.push('');
  workspaces.forEach((workspace) => {
    lines.push(`### ${workspace.label}`);
    lines.push('');
    workspace.entrypoints.forEach((entrypoint) => {
      lines.push(`- \`${entrypoint}\``);
      const deps = workspace.entrypointDependencies[entrypoint] || [];
      deps.slice(0, 20).forEach((dep) => {
        lines.push(`  - \`${dep}\``);
      });
    });
    lines.push('');
  });

  return `${lines.join('\n').trim()}\n`;
}

function getGitValue(args) {
  const { execSync } = require('child_process');
  return execSync(`git ${args}`, { cwd: repoRoot, encoding: 'utf8' }).trim();
}

function main() {
  ensureDir(outputDir);

  const workspaces = WORKSPACES.map(buildWorkspaceGraph);
  const backendRoutes = extractBackendRouteSummary();
  const adminRoutes = extractAdminRouteSummary();
  const mobileRoutes = extractMobileRouteSummary();

  const graph = {
    generatedAt: new Date().toISOString(),
    repo: {
      branch: getGitValue('rev-parse --abbrev-ref HEAD'),
      remote: getGitValue('config --get remote.origin.url'),
    },
    workspaces,
    backendRoutes,
    adminRoutes,
    mobileRoutes,
  };

  graph.mermaid = buildMermaid(workspaces, backendRoutes, adminRoutes, mobileRoutes);

  fs.writeFileSync(jsonOutputPath, `${JSON.stringify(graph, null, 2)}\n`);
  fs.writeFileSync(markdownOutputPath, toMarkdown(graph));

  console.log(`Wrote ${path.relative(repoRoot, jsonOutputPath)}`);
  console.log(`Wrote ${path.relative(repoRoot, markdownOutputPath)}`);
}

main();
