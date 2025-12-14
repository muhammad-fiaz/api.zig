import { defineConfig } from 'vitepress'

export default defineConfig({
  title: "api.zig",
  description: "High-performance, multi-threaded HTTP API framework for Zig",
  base: '/api.zig/',
  
  head: [
    ['meta', { name: 'theme-color', content: '#f7a41d' }],
    ['meta', { name: 'og:type', content: 'website' }],
    ['meta', { name: 'og:site_name', content: 'api.zig' }],
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
            { text: 'Context', link: '/guide/context' }
          ]
        },
        {
          text: 'Advanced',
          items: [
            { text: 'Multi-Threading', link: '/guide/multi-threading' },
            { text: 'OpenAPI', link: '/guide/openapi' },
            { text: 'Validation', link: '/guide/validation' },
            { text: 'Error Handling', link: '/guide/error-handling' },
            { text: 'JSON', link: '/guide/json' },
            { text: 'Logging', link: '/guide/logging' }
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
