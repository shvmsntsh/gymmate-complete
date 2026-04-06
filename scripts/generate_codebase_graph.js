#!/usr/bin/env node

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const repoRoot = path.resolve(__dirname, '..');
const docsDir = path.join(repoRoot, 'docs');
const storeDir = path.join(repoRoot, '.code-knowledge-graph');
const graphJsonPath = path.join(storeDir, 'graph.json');
const impactJsonPath = path.join(storeDir, 'last-impact.json');
const contextJsonPath = path.join(storeDir, 'last-context.json');
const contextMdPath = path.join(storeDir, 'last-context.md');
const summaryJsonPath = path.join(docsDir, 'codebase-graph.json');
const summaryMdPath = path.join(docsDir, 'codebase-graph.md');
const usageMdPath = path.join(docsDir, 'knowledge-graph-usage.md');

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

const DEFAULT_DEPTH = 2;

function ensureDir(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

function readText(filePath) {
  return fs.readFileSync(filePath, 'utf8');
}

function writeJson(filePath, value) {
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`);
}

function sha256(input) {
  return crypto.createHash('sha256').update(input).digest('hex');
}

function git(args) {
  return execSync(`git ${args}`, { cwd: repoRoot, encoding: 'utf8' }).trim();
}

function normalizePath(inputPath) {
  const absolute = path.isAbsolute(inputPath)
    ? inputPath
    : path.join(repoRoot, inputPath);
  return path.relative(repoRoot, absolute).replace(/\\/g, '/');
}

function walkFiles(relativeRoot, includeExtensions, ignoreDirs) {
  const absoluteRoot = path.join(repoRoot, relativeRoot);
  const results = [];

  function visit(currentDir) {
    for (const entry of fs.readdirSync(currentDir, { withFileTypes: true })) {
      if (entry.name.startsWith('.git')) continue;
      if (ignoreDirs.has(entry.name)) continue;

      const absolutePath = path.join(currentDir, entry.name);
      if (entry.isDirectory()) {
        visit(absolutePath);
        continue;
      }

      if (!includeExtensions.has(path.extname(entry.name))) continue;
      results.push(path.relative(repoRoot, absolutePath).replace(/\\/g, '/'));
    }
  }

  if (fs.existsSync(absoluteRoot)) visit(absoluteRoot);
  return results.sort();
}

function listTopLevelTree(relativeDir, maxDepth = 2) {
  const absoluteDir = path.join(repoRoot, relativeDir);
  if (!fs.existsSync(absoluteDir)) return [];

  const lines = [relativeDir];

  function visit(currentDir, depth, prefix) {
    if (depth > maxDepth) return;

    const entries = fs
      .readdirSync(currentDir, { withFileTypes: true })
      .filter((entry) => {
        if (entry.name.startsWith('.')) return false;
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

  visit(absoluteDir, 1, '');
  return lines;
}

function normalizeJsLikeImport(fromFile, specifier) {
  if (!specifier) return null;
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
        return path.relative(repoRoot, candidate).replace(/\\/g, '/');
      }
    }
    return path.relative(repoRoot, candidateBase).replace(/\\/g, '/');
  }

  if (specifier.startsWith('package:gymmate_mobile/')) {
    return specifier.replace('package:gymmate_mobile/', 'gymmate_mobile/lib/');
  }

  return null;
}

function normalizeDartImport(fromFile, specifier) {
  if (!specifier) return null;
  if (specifier.startsWith('package:gymmate_mobile/')) {
    return specifier.replace('package:gymmate_mobile/', 'gymmate_mobile/lib/');
  }
  if (specifier.startsWith('.')) {
    const baseDir = path.dirname(path.join(repoRoot, fromFile));
    return path.relative(repoRoot, path.normalize(path.join(baseDir, specifier))).replace(/\\/g, '/');
  }
  return null;
}

function extractScriptSource(filePath, source) {
  if (path.extname(filePath) !== '.vue') return source;
  return Array.from(source.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/g))
    .map((match) => match[1])
    .join('\n');
}

function extractJsLikeDependencies(filePath, source) {
  const scriptSource = extractScriptSource(filePath, source);
  const imports = new Set();
  const externalImports = new Set();

  const patterns = [
    /import\s+(?:[^'"]+?\s+from\s+)?["']([^"']+)["']/g,
    /require\(\s*["']([^"']+)["']\s*\)/g,
  ];

  for (const pattern of patterns) {
    let match;
    while ((match = pattern.exec(scriptSource)) !== null) {
      const specifier = match[1];
      const normalized = normalizeJsLikeImport(filePath, specifier);
      if (normalized) imports.add(normalized);
      else externalImports.add(specifier);
    }
  }

  return {
    imports: Array.from(imports).sort(),
    externalImports: Array.from(externalImports).sort(),
  };
}

function extractDartDependencies(filePath, source) {
  const imports = new Set();
  const externalImports = new Set();
  let match;
  const pattern = /import\s+['"]([^'"]+)['"]\s*;/g;
  while ((match = pattern.exec(source)) !== null) {
    const specifier = match[1];
    const normalized = normalizeDartImport(filePath, specifier);
    if (normalized) imports.add(normalized);
    else externalImports.add(specifier);
  }
  return {
    imports: Array.from(imports).sort(),
    externalImports: Array.from(externalImports).sort(),
  };
}

function uniqueSorted(values) {
  return Array.from(new Set(values.filter(Boolean))).sort();
}

function extractFileSymbols(filePath, source) {
  const ext = path.extname(filePath);
  const scriptSource = extractScriptSource(filePath, source);
  const symbolNodes = [];

  function push(kind, name, line) {
    if (!name) return;
    symbolNodes.push({
      id: `${filePath}::${kind}:${name}`,
      kind,
      name,
      file: filePath,
      line,
    });
  }

  if (ext === '.js' || ext === '.vue') {
    let match;
    const patterns = [
      { kind: 'class', regex: /class\s+([A-Z]\w*)/g },
      { kind: 'function', regex: /function\s+([A-Za-z_]\w*)\s*\(/g },
      { kind: 'function', regex: /const\s+([A-Za-z_]\w*)\s*=\s*(?:async\s*)?\(/g },
      { kind: 'function', regex: /const\s+([A-Za-z_]\w*)\s*=\s*(?:async\s*)?[^=]*=>/g },
    ];
    patterns.forEach(({ kind, regex }) => {
      while ((match = regex.exec(scriptSource)) !== null) {
        push(kind, match[1], lineNumberAtOffset(scriptSource, match.index));
      }
    });
  } else if (ext === '.dart') {
    let match;
    const patterns = [
      { kind: 'class', regex: /class\s+([A-Z]\w*)/g },
      { kind: 'function', regex: /(?:Future<[^>]+>|Future|void|Widget|String|int|double|bool)\s+([a-zA-Z_]\w*)\s*\(/g },
    ];
    patterns.forEach(({ kind, regex }) => {
      while ((match = regex.exec(source)) !== null) {
        push(kind, match[1], lineNumberAtOffset(source, match.index));
      }
    });
  }

  return uniqueSorted(symbolNodes.map((node) => node.id)).map((id) =>
    symbolNodes.find((node) => node.id === id),
  );
}

function lineNumberAtOffset(source, offset) {
  return source.slice(0, offset).split('\n').length;
}

function workspaceForFile(filePath) {
  return WORKSPACES.find((workspace) => filePath.startsWith(`${workspace.root}/`) || filePath === workspace.root);
}

function parseFile(filePath) {
  const absolutePath = path.join(repoRoot, filePath);
  const source = readText(absolutePath);
  const ext = path.extname(filePath);
  const dependencyInfo =
    ext === '.dart'
      ? extractDartDependencies(filePath, source)
      : extractJsLikeDependencies(filePath, source);
  const symbols = extractFileSymbols(filePath, source);
  const workspace = workspaceForFile(filePath);

  return {
    path: filePath,
    workspace: workspace ? workspace.key : 'unknown',
    hash: sha256(source),
    size: Buffer.byteLength(source, 'utf8'),
    imports: dependencyInfo.imports,
    externalImports: dependencyInfo.externalImports,
    symbols,
  };
}

function loadExistingGraph() {
  if (!fs.existsSync(graphJsonPath)) return null;
  return JSON.parse(readText(graphJsonPath));
}

function buildGraph() {
  ensureDir(docsDir);
  ensureDir(storeDir);

  const existing = loadExistingGraph();
  const previousFiles = existing?.files || {};
  const allFiles = WORKSPACES.flatMap((workspace) =>
    walkFiles(workspace.root, workspace.includeExtensions, workspace.ignoreDirs),
  );

  const files = {};
  const changedFiles = [];
  const reusedFiles = [];

  allFiles.forEach((filePath) => {
    const source = readText(path.join(repoRoot, filePath));
    const hash = sha256(source);
    const existingNode = previousFiles[filePath];
    if (existingNode && existingNode.hash === hash) {
      files[filePath] = existingNode;
      reusedFiles.push(filePath);
    } else {
      files[filePath] = parseFile(filePath);
      changedFiles.push(filePath);
    }
  });

  const deletedFiles = Object.keys(previousFiles).filter((filePath) => !files[filePath]);
  const reverseImports = {};
  const symbolIndex = {};
  const edges = [];

  Object.values(files).forEach((node) => {
    node.imports.forEach((target) => {
      if (!reverseImports[target]) reverseImports[target] = [];
      reverseImports[target].push(node.path);
      edges.push({ kind: 'IMPORTS_FROM', source: node.path, target });
    });

    node.symbols.forEach((symbol) => {
      symbolIndex[symbol.id] = symbol;
      edges.push({ kind: 'CONTAINS', source: node.path, target: symbol.id });
    });
  });

  Object.keys(reverseImports).forEach((key) => {
    reverseImports[key] = uniqueSorted(reverseImports[key]);
  });

  const backendRoutes = extractBackendRouteSummary();
  const adminRoutes = extractAdminRouteSummary();
  const mobileRoutes = extractMobileRouteSummary();
  const workspaces = buildWorkspaceSummaries(files, edges);

  const graph = {
    schemaVersion: 2,
    generatedAt: new Date().toISOString(),
    repo: {
      branch: git('rev-parse --abbrev-ref HEAD'),
      remote: git('config --get remote.origin.url'),
      head: git('rev-parse HEAD'),
    },
    files,
    reverseImports,
    symbolIndex,
    edges,
    workspaces,
    indexes: {
      backendRoutes,
      adminRoutes,
      mobileRoutes,
    },
    incremental: {
      scannedFiles: allFiles.length,
      reparsedFiles: changedFiles,
      reusedFiles,
      deletedFiles,
    },
  };

  writeJson(graphJsonPath, graph);
  writeSummaryArtifacts(graph);

  return graph;
}

function buildWorkspaceSummaries(files, edges) {
  return WORKSPACES.map((workspace) => {
    const workspaceFiles = Object.values(files).filter((node) => node.workspace === workspace.key);
    const workspaceEdgeCount = edges.filter(
      (edge) =>
        edge.kind === 'IMPORTS_FROM' &&
        files[edge.source] &&
        files[edge.source].workspace === workspace.key,
    ).length;
    const externalImports = uniqueSorted(
      workspaceFiles.flatMap((node) => node.externalImports),
    );

    const entrypointDependencies = {};
    workspace.entrypoints.forEach((entrypoint) => {
      entrypointDependencies[entrypoint] = files[entrypoint]?.imports || [];
    });

    return {
      key: workspace.key,
      label: workspace.label,
      root: workspace.root,
      entrypoints: workspace.entrypoints,
      entrypointDependencies,
      fileCount: workspaceFiles.length,
      edgeCount: workspaceEdgeCount,
      externalImports,
      tree: listTopLevelTree(workspace.root),
    };
  });
}

function extractBackendRouteSummary() {
  const appPath = path.join(repoRoot, 'gymmate_backend/app.js');
  if (!fs.existsSync(appPath)) return [];

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
    if (!routeSpecifier) continue;
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
  if (!fs.existsSync(absolutePath)) return [];

  const source = readText(absolutePath);
  const controllerMap = new Map();
  let match;

  const destructuredPattern = /const\s*\{\s*([^}]+)\}\s*=\s*require\(['"](.+?)['"]\);/g;
  while ((match = destructuredPattern.exec(source)) !== null) {
    const names = match[1].split(',').map((value) => value.trim()).filter(Boolean);
    const target = normalizeJsLikeImport(routeFile, match[2]);
    names.forEach((name) => controllerMap.set(name, target));
  }

  const defaultPattern = /const\s+(\w+)\s*=\s*require\(['"](.+?)['"]\);/g;
  while ((match = defaultPattern.exec(source)) !== null) {
    controllerMap.set(match[1], normalizeJsLikeImport(routeFile, match[2]));
  }

  const handlers = [];
  const routePattern = /router\.(get|post|put|patch|delete)\(\s*['"]([^'"]+)['"]\s*,([\s\S]*?)\);/g;
  while ((match = routePattern.exec(source)) !== null) {
    const method = match[1].toUpperCase();
    const routePath = match[2];
    const handlerSource = match[3].replace(/\s+/g, ' ').trim();
    const referencedControllers = Array.from(handlerSource.matchAll(/(\w+)\.(\w+)/g)).map(
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
      referencedControllers,
    });
  }

  return handlers;
}

function extractAdminRouteSummary() {
  const routerFile = path.join(repoRoot, 'gymmate_admin_vite/src/router/index.js');
  if (!fs.existsSync(routerFile)) return [];

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
  if (!fs.existsSync(mainFile)) return { namedRoutes: [], authGateTargets: [] };

  const source = readText(mainFile);
  const namedRoutes = [];
  const routesBlockMatch = source.match(/routes:\s*\{([\s\S]*?)\}/m);
  if (routesBlockMatch) {
    const routePattern = /['"]([^'"]+)['"]\s*:\s*\(context\)\s*=>\s*const\s+(\w+)/g;
    let match;
    while ((match = routePattern.exec(routesBlockMatch[1])) !== null) {
      namedRoutes.push({ route: match[1], widget: match[2] });
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
    namedRoutes,
    authGateTargets: uniqueSorted(authGateTargets),
  };
}

function relatedRoutesForFiles(graph, files) {
  const fileSet = new Set(files);
  const backend = graph.indexes.backendRoutes.filter(
    (mount) =>
      fileSet.has(mount.routeFile) ||
      mount.handlers.some((handler) =>
        handler.referencedControllers.some((controller) => controller.file && fileSet.has(controller.file)),
      ),
  );
  const admin = graph.indexes.adminRoutes.filter(
    (route) => route.component && fileSet.has(route.component),
  );
  return { backend, admin };
}

function computeImpact(graph, changedFiles, depth = DEFAULT_DEPTH) {
  const normalizedChanged = uniqueSorted(changedFiles.map(normalizePath)).filter(
    (filePath) => graph.files[filePath],
  );
  const visited = new Set(normalizedChanged);
  const queue = normalizedChanged.map((filePath) => ({ filePath, depth: 0 }));

  while (queue.length) {
    const current = queue.shift();
    if (current.depth >= depth) continue;

    const node = graph.files[current.filePath];
    const forward = node?.imports || [];
    const backward = graph.reverseImports[current.filePath] || [];

    [...forward, ...backward].forEach((neighbor) => {
      if (!graph.files[neighbor] || visited.has(neighbor)) return;
      visited.add(neighbor);
      queue.push({ filePath: neighbor, depth: current.depth + 1 });
    });
  }

  const impactedFiles = Array.from(visited).sort();
  const routeInfo = relatedRoutesForFiles(graph, impactedFiles);
  const impactedWorkspaces = uniqueSorted(
    impactedFiles.map((filePath) => graph.files[filePath]?.workspace),
  );
  const directDependents = {};
  normalizedChanged.forEach((filePath) => {
    directDependents[filePath] = graph.reverseImports[filePath] || [];
  });

  const impactedSymbols = impactedFiles
    .flatMap((filePath) => graph.files[filePath].symbols || [])
    .slice(0, 30);

  return {
    generatedAt: new Date().toISOString(),
    depth,
    changedFiles: normalizedChanged,
    impactedFiles,
    impactedWorkspaces,
    directDependents,
    relatedRoutes: routeInfo,
    impactedSymbols,
  };
}

function formatContextMarkdown(context) {
  const lines = [];
  lines.push('# Knowledge Graph Context');
  lines.push('');
  lines.push(`Generated: ${context.generatedAt}`);
  lines.push('');
  lines.push('## Changed Files');
  lines.push('');
  context.changedFiles.forEach((filePath) => lines.push(`- \`${filePath}\``));
  lines.push('');
  lines.push('## Recommended Read Order');
  lines.push('');
  context.recommendedReadOrder.forEach((filePath, index) =>
    lines.push(`${index + 1}. \`${filePath}\``),
  );
  lines.push('');
  lines.push('## Impact Summary');
  lines.push('');
  lines.push(`- Impacted files: ${context.impactedFiles.length}`);
  lines.push(`- Workspaces: ${context.impactedWorkspaces.map((item) => `\`${item}\``).join(', ')}`);
  lines.push(`- Backend routes: ${context.relatedRoutes.backend.length}`);
  lines.push(`- Admin routes: ${context.relatedRoutes.admin.length}`);
  lines.push('');
  if (context.relatedRoutes.backend.length) {
    lines.push('## Related Backend Routes');
    lines.push('');
    context.relatedRoutes.backend.forEach((mount) => {
      lines.push(`- \`${mount.mountPath}\` via \`${mount.routeFile}\``);
    });
    lines.push('');
  }
  if (context.relatedRoutes.admin.length) {
    lines.push('## Related Admin Routes');
    lines.push('');
    context.relatedRoutes.admin.forEach((route) => {
      lines.push(`- \`${route.name}\` -> \`${route.component}\``);
    });
    lines.push('');
  }
  lines.push('## Prompt Hint');
  lines.push('');
  lines.push(
    'Start with the changed files and recommended read order. Only open additional impacted files if the current file references them directly or the task touches one of the listed routes.',
  );
  return `${lines.join('\n').trim()}\n`;
}

function buildContext(graph, changedFiles, depth = DEFAULT_DEPTH) {
  const impact = computeImpact(graph, changedFiles, depth);
  const recommendedReadOrder = uniqueSorted([
    ...impact.changedFiles,
    ...impact.changedFiles.flatMap((filePath) => graph.files[filePath]?.imports || []),
    ...impact.changedFiles.flatMap((filePath) => graph.reverseImports[filePath] || []),
  ]).slice(0, 20);

  const context = {
    ...impact,
    impactedFiles: impact.impactedFiles.slice(0, 40),
    recommendedReadOrder,
    graphHead: graph.repo.head,
  };

  writeJson(impactJsonPath, impact);
  writeJson(contextJsonPath, context);
  fs.writeFileSync(contextMdPath, formatContextMarkdown(context));
  return context;
}

function buildMermaid(graph) {
  const lines = ['graph TD'];
  lines.push('  Repo["gymmate-complete / knowledge graph"]');
  lines.push('  Repo --> Backend["Backend API"]');
  lines.push('  Repo --> Admin["Admin Web"]');
  lines.push('  Repo --> Mobile["Mobile App"]');

  graph.indexes.backendRoutes.forEach((mount) => {
    lines.push(`  Backend --> ${sanitizeNodeId(`backend-${mount.mountPath}`)}["${mount.mountPath}"]`);
  });
  graph.indexes.adminRoutes.forEach((route) => {
    lines.push(`  Admin --> ${sanitizeNodeId(`admin-${route.name}`)}["${route.name}: ${route.path}"]`);
  });
  graph.indexes.mobileRoutes.authGateTargets.forEach((target) => {
    lines.push(`  Mobile --> ${sanitizeNodeId(`mobile-${target}`)}["${target}"]`);
  });
  lines.push('  Admin --> Backend');
  lines.push('  Mobile --> Backend');
  return lines.join('\n');
}

function sanitizeNodeId(value) {
  return value.replace(/[^A-Za-z0-9_]/g, '_');
}

function toSummaryMarkdown(graph) {
  const lines = [];
  lines.push('# Codebase Graph');
  lines.push('');
  lines.push(`Generated: ${graph.generatedAt}`);
  lines.push('');
  lines.push(`Branch: \`${graph.repo.branch}\``);
  lines.push('');
  lines.push(`Remote: \`${graph.repo.remote}\``);
  lines.push('');
  lines.push('## Purpose');
  lines.push('');
  lines.push(
    'Persistent repo knowledge graph for low-token code navigation. Use it to identify the smallest relevant context before opening source files.',
  );
  lines.push('');
  lines.push('## Workspace Summary');
  lines.push('');
  graph.workspaces.forEach((workspace) => {
    lines.push(
      `- \`${workspace.label}\`: ${workspace.fileCount} files, ${workspace.edgeCount} import edges`,
    );
  });
  lines.push('');
  lines.push('## Incremental Status');
  lines.push('');
  lines.push(`- Reparsed files this run: ${graph.incremental.reparsedFiles.length}`);
  lines.push(`- Reused unchanged files: ${graph.incremental.reusedFiles.length}`);
  lines.push('');
  lines.push('## System Graph');
  lines.push('');
  lines.push('```mermaid');
  lines.push(buildMermaid(graph));
  lines.push('```');
  lines.push('');
  lines.push('## Backend API Mounts');
  lines.push('');
  graph.indexes.backendRoutes.forEach((mount) => {
    lines.push(`### ${mount.mountPath}`);
    lines.push('');
    lines.push(`- Route file: \`${mount.routeFile}\``);
    mount.handlers.slice(0, 12).forEach((handler) => {
      const refs = handler.referencedControllers
        .map((item) => (item.file ? `${item.file}#${item.action}` : `${item.controllerAlias}.${item.action}`))
        .join(', ');
      lines.push(`- \`${handler.method} ${handler.path}\` -> ${refs || handler.rawHandler}`);
    });
    lines.push('');
  });
  lines.push('## Admin Routes');
  lines.push('');
  graph.indexes.adminRoutes.forEach((route) => {
    lines.push(`- \`${route.path}\` -> \`${route.component}\` (${route.name})`);
  });
  lines.push('');
  lines.push('## Mobile Navigation Anchors');
  lines.push('');
  graph.indexes.mobileRoutes.namedRoutes.forEach((route) => {
    lines.push(`- Named route \`${route.route}\` -> \`${route.widget}\``);
  });
  lines.push(
    `- Auth gate targets: ${graph.indexes.mobileRoutes.authGateTargets.map((item) => `\`${item}\``).join(', ')}`,
  );
  lines.push('');
  lines.push('## Trees');
  lines.push('');
  graph.workspaces.forEach((workspace) => {
    lines.push(`### ${workspace.label}`);
    lines.push('');
    lines.push('```text');
    workspace.tree.forEach((line) => lines.push(line));
    lines.push('```');
    lines.push('');
  });
  return `${lines.join('\n').trim()}\n`;
}

function toUsageMarkdown(graph) {
  const lines = [];
  lines.push('# Knowledge Graph Usage');
  lines.push('');
  lines.push('## Goal');
  lines.push('');
  lines.push(
    'Minimize token usage by querying the persisted graph first, then reading only the changed files and their blast radius.',
  );
  lines.push('');
  lines.push('## Commands');
  lines.push('');
  lines.push('- `node scripts/generate_codebase_graph.js build`');
  lines.push('- `node scripts/generate_codebase_graph.js impact <file> [more files]`');
  lines.push('- `node scripts/generate_codebase_graph.js context <file> [more files]`');
  lines.push('- `node scripts/generate_codebase_graph.js stats`');
  lines.push('');
  lines.push('## Recommended Workflow');
  lines.push('');
  lines.push('1. Rebuild the graph after notable edits or before a review.');
  lines.push('2. Run `context` on the changed files.');
  lines.push('3. Read only the files in `.code-knowledge-graph/last-context.md` unless the task clearly spills beyond that blast radius.');
  lines.push('4. Refresh the graph after the change so the next task starts from current structure.');
  lines.push('');
  lines.push('## Stored Artifacts');
  lines.push('');
  lines.push('- `.code-knowledge-graph/graph.json`: persistent graph store with file hashes for incremental reuse');
  lines.push('- `.code-knowledge-graph/last-impact.json`: most recent blast-radius query');
  lines.push('- `.code-knowledge-graph/last-context.json`: compact machine-readable context pack');
  lines.push('- `.code-knowledge-graph/last-context.md`: compact human-readable context pack');
  lines.push('- `docs/codebase-graph.md`: repo-level architecture summary');
  lines.push('');
  lines.push('## Prompt Pattern');
  lines.push('');
  lines.push('Use the knowledge graph first. Refresh it if stale, run context for the changed files, and limit source reads to the recommended read order plus directly impacted files.');
  lines.push('');
  lines.push(`Current graph head: \`${graph.repo.head}\``);
  return `${lines.join('\n').trim()}\n`;
}

function writeSummaryArtifacts(graph) {
  writeJson(summaryJsonPath, {
    generatedAt: graph.generatedAt,
    repo: graph.repo,
    workspaces: graph.workspaces,
    backendRoutes: graph.indexes.backendRoutes,
    adminRoutes: graph.indexes.adminRoutes,
    mobileRoutes: graph.indexes.mobileRoutes,
    incremental: graph.incremental,
  });
  fs.writeFileSync(summaryMdPath, toSummaryMarkdown(graph));
  fs.writeFileSync(usageMdPath, toUsageMarkdown(graph));
}

function printStats(graph) {
  const stats = {
    generatedAt: graph.generatedAt,
    head: graph.repo.head,
    fileCount: Object.keys(graph.files).length,
    edgeCount: graph.edges.length,
    backendMounts: graph.indexes.backendRoutes.length,
    adminRoutes: graph.indexes.adminRoutes.length,
    mobileNamedRoutes: graph.indexes.mobileRoutes.namedRoutes.length,
    reparsedFiles: graph.incremental.reparsedFiles.length,
  };
  console.log(JSON.stringify(stats, null, 2));
}

function printImpact(impact) {
  console.log(JSON.stringify(impact, null, 2));
}

function printContext(context) {
  console.log(JSON.stringify(context, null, 2));
}

function usage() {
  console.log(
    [
      'Usage:',
      '  node scripts/generate_codebase_graph.js build',
      '  node scripts/generate_codebase_graph.js impact <file> [more files]',
      '  node scripts/generate_codebase_graph.js context <file> [more files]',
      '  node scripts/generate_codebase_graph.js stats',
    ].join('\n'),
  );
}

function main() {
  const command = process.argv[2] || 'build';
  if (!['build', 'impact', 'context', 'stats'].includes(command)) {
    usage();
    process.exit(1);
  }

  const graph = buildGraph();

  if (command === 'build') {
    console.log(`Wrote ${path.relative(repoRoot, graphJsonPath)}`);
    console.log(`Wrote ${path.relative(repoRoot, summaryMdPath)}`);
    console.log(`Wrote ${path.relative(repoRoot, usageMdPath)}`);
    return;
  }

  if (command === 'stats') {
    printStats(graph);
    return;
  }

  const changedFiles = process.argv.slice(3);
  if (!changedFiles.length) {
    console.error('Please pass at least one changed file path.');
    process.exit(1);
  }

  if (command === 'impact') {
    const impact = computeImpact(graph, changedFiles);
    writeJson(impactJsonPath, impact);
    printImpact(impact);
    return;
  }

  if (command === 'context') {
    const context = buildContext(graph, changedFiles);
    printContext(context);
  }
}

main();
