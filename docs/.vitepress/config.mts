import { defineConfig } from 'vitepress'

export default defineConfig({
  title: "api.zig",
  description: "High-performance, multi-threaded HTTP API framework for Zig with GraphQL, WebSocket, and real-time support",
  base: '/api.zig/',
  
  head: [
    ['meta', { name: 'theme-color', content: '#f7a41d' }],
    ['meta', { name: 'og:type', content: 'website' }],
    ['meta', { name: 'og:site_name', content: 'api.zig' }],
    ['meta', { name: 'keywords', content: 'zig, api, graphql, websocket, http, framework, rest, openapi' }],
  ],

  themeConfig: {
    logo: '/logo.png',
    
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Guide', link: '/guide/getting-started' },
      { text: 'API', link: '/api/' },
      { text: 'Examples', link: '/examples/' },
      {
        text: 'v0.0.1',
        items: [
          { text: 'Releases', link: 'https://github.com/muhammad-fiaz/api.zig/releases' },
          { text: 'GitHub', link: 'https://github.com/muhammad-fiaz/api.zig' }
        ]
      }
    ],

    sidebar: {
      '/guide/': [
        {
          text: 'Introduction',
          items: [
            { text: 'Getting Started', link: '/guide/getting-started' },
            { text: 'Installation', link: '/guide/installation' },
            { text: 'Quick Start', link: '/guide/quick-start' }
          ]
        },
        {
          text: 'Core Concepts',
          items: [
            { text: 'Routing', link: '/guide/routing' },
            { text: 'Handlers', link: '/guide/handlers' },
            { text: 'Responses', link: '/guide/responses' },
            { text: 'Path Parameters', link: '/guide/path-parameters' },
            { text: 'Context', link: '/guide/context' },
            { text: 'Middleware', link: '/guide/middleware' }
          ]
        },
        {
          text: 'Advanced',
          items: [
            { text: 'Multi-Threading', link: '/guide/multi-threading' },
            { text: 'OpenAPI', link: '/guide/openapi' },
            { text: 'Validation', link: '/guide/validation' },
            { text: 'Dependency Injection', link: '/guide/dependency-injection' },
            { text: 'Security', link: '/guide/security' },
            { text: 'Sub-Applications', link: '/guide/sub-applications' },
            { text: 'Error Handling', link: '/guide/error-handling' },
            { text: 'JSON', link: '/guide/json' },
            { text: 'Logging', link: '/guide/logging' }
          ]
        },
        {
          text: 'GraphQL',
          collapsed: false,
          items: [
            { text: 'Introduction', link: '/guide/graphql' },
            { text: 'Schema Definition', link: '/guide/graphql-schema' },
            { text: 'Resolvers', link: '/guide/graphql-resolvers' },
            { text: 'Subscriptions', link: '/guide/graphql-subscriptions' },
            { text: 'UI & Playground', link: '/guide/graphql-ui' }
          ]
        },
        {
          text: 'Real-time',
          collapsed: false,
          items: [
            { text: 'WebSocket', link: '/guide/websocket' },
            { text: 'Sessions', link: '/guide/sessions' },
            { text: 'Caching', link: '/guide/caching' }
          ]
        },
        {
          text: 'Production',
          collapsed: false,
          items: [
            { text: 'Metrics', link: '/guide/metrics' },
            { text: 'Health Checks', link: '/guide/health-checks' },
            { text: 'Deployment', link: '/guide/deployment' }
          ]
        }
      ],
      '/api/': [
        {
          text: 'API Reference',
          items: [
            { text: 'Overview', link: '/api/' },
            { text: 'App', link: '/api/app' },
            { text: 'Response', link: '/api/response' },
            { text: 'Context', link: '/api/context' },
            { text: 'Router', link: '/api/router' },
            { text: 'Server', link: '/api/server' },
            { text: 'HTTP', link: '/api/http' },
            { text: 'JSON', link: '/api/json' },
            { text: 'Client', link: '/api/client' },
            { text: 'Middleware', link: '/api/middleware' },
            { text: 'Static Files', link: '/api/static' },
            { text: 'Extractors', link: '/api/extractors' },
            { text: 'Validation', link: '/api/validation' },
            { text: 'OpenAPI', link: '/api/openapi' },
            { text: 'Logger', link: '/api/logger' },
            { text: 'Report', link: '/api/report' },
            { text: 'Version', link: '/api/version' }
          ]
        },
        {
          text: 'GraphQL',
          collapsed: false,
          items: [
            { text: 'GraphQL', link: '/api/graphql' },
            { text: 'Schema', link: '/api/graphql-schema' },
            { text: 'Resolvers', link: '/api/graphql-resolvers' },
            { text: 'UI Providers', link: '/api/graphql-ui' },
            { text: 'Configuration', link: '/api/graphql-config' }
          ]
        },
        {
          text: 'Real-time',
          collapsed: false,
          items: [
            { text: 'WebSocket', link: '/api/websocket' },
            { text: 'Cache', link: '/api/cache' },
            { text: 'Session', link: '/api/session' }
          ]
        },
        {
          text: 'Monitoring',
          collapsed: false,
          items: [
            { text: 'Metrics', link: '/api/metrics' }
          ]
        }
      ],
      '/examples/': [
        {
          text: 'Examples',
          items: [
            { text: 'Overview', link: '/examples/' },
            { text: 'REST API', link: '/examples/rest-api' },
            { text: 'HTML Pages', link: '/examples/html-pages' },
            { text: 'Path Parameters', link: '/examples/path-parameters' }
          ]
        },
        {
          text: 'GraphQL Examples',
          collapsed: false,
          items: [
            { text: 'Basic GraphQL', link: '/examples/graphql-basic' },
            { text: 'GraphQL Subscriptions', link: '/examples/graphql-subscriptions' },
            { text: 'Federation', link: '/examples/graphql-federation' }
          ]
        },
        {
          text: 'Real-time Examples',
          collapsed: false,
          items: [
            { text: 'WebSocket Chat', link: '/examples/websocket-chat' },
            { text: 'Live Dashboard', link: '/examples/live-dashboard' }
          ]
        }
      ]
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/muhammad-fiaz/api.zig' }
    ],

    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright © 2025 Muhammad Fiaz'
    },

    editLink: {
      pattern: 'https://github.com/muhammad-fiaz/api.zig/edit/main/docs/:path',
      text: 'Edit this page on GitHub'
    },

    search: {
      provider: 'local'
    }
  }
})
