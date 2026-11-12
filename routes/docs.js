const express = require('express');
const router = express.Router();

const openApiSpec = {
  openapi: "3.0.0",
  info: {
    title: "Gold & Silver Pawn Loan Management ERP API",
    version: "1.0.0",
    description: "Complete Node.js Express REST API for Gold & Silver Pawn Management ERP system with Central Ledger Staff Attribution and Two-Step Gmail OTP Authentication."
  },
  servers: [
    {
      url: "/",
      description: "Current Server"
    }
  ],
  components: {
    securitySchemes: {
      BearerAuth: {
        type: "http",
        scheme: "bearer",
        bearerFormat: "JWT"
      }
    }
  },
  paths: {
    "/api/auth/login": {
      post: {
        summary: "Step 1: Admin/Staff Credential Login",
        description: "Validates username & password against MySQL database, generates 4-digit OTP, sends email to pandetiprabhash@gmail.com, and returns challenge ID.",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                properties: {
                  username: { type: "string", example: "admin" },
                  password: { type: "string", example: "admin123" }
                },
                required: ["username", "password"]
              }
            }
          }
        },
        responses: {
          "200": { description: "Credentials valid. Returns challengeId and requires_otp: true." },
          "401": { description: "Invalid username or password." },
          "403": { description: "User account inactive." }
        }
      }
    },
    "/api/auth/verify-otp": {
      post: {
        summary: "Step 2: Gmail OTP Verification",
        description: "Verifies the 4-digit OTP and challenge ID, generates JWT access and refresh tokens, and completes login.",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                properties: {
                  challengeId: { type: "string", example: "CHALLENGE-1793332498-A1B2C" },
                  otp: { type: "string", example: "1234" }
                },
                required: ["challengeId", "otp"]
              }
            }
          }
        },
        responses: {
          "200": { description: "OTP verified successfully. Returns JWT token and authenticated user profile." },
          "401": { description: "Invalid OTP code." },
          "410": { description: "OTP expired." },
          "429": { description: "Maximum OTP attempts exceeded." }
        }
      }
    },
    "/api/auth/resend-otp": {
      post: {
        summary: "Resend 4-Digit Gmail OTP",
        description: "Enforces 60s cooldown, invalidates old OTP, generates new 4-digit OTP, and sends email to pandetiprabhash@gmail.com.",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                properties: {
                  challengeId: { type: "string", example: "CHALLENGE-1793332498-A1B2C" }
                },
                required: ["challengeId"]
              }
            }
          }
        },
        responses: {
          "200": { description: "New 4-digit OTP sent successfully." },
          "429": { description: "Cooldown period active (wait 60s)." }
        }
      }
    },
    "/api/central-ledger/transactions": {
      get: {
        summary: "Central Ledger Transactions (Staff Attributed)",
        description: "Retrieves complete financial & collateral transaction ledger with automatic staff attribution and snapshot details.",
        security: [{ BearerAuth: [] }],
        parameters: [
          { name: "search", in: "query", schema: { type: "string" }, description: "Search by code, customer, loan, staff, or remarks" },
          { name: "staffId", in: "query", schema: { type: "string" }, description: "Filter by specific staff ID or 'ALL'" },
          { name: "eventType", in: "query", schema: { type: "string" }, description: "Filter by event type (e.g. LOAN_CREATED, PAYMENT_COLLECTED, GOLD_RELEASED)" },
          { name: "fromDate", in: "query", schema: { type: "string", format: "date" }, description: "Filter from date (YYYY-MM-DD)" },
          { name: "toDate", in: "query", schema: { type: "string", format: "date" }, description: "Filter to date (YYYY-MM-DD)" },
          { name: "page", in: "query", schema: { type: "integer", default: 1 } },
          { name: "limit", in: "query", schema: { type: "integer", default: 25 } }
        ],
        responses: {
          "200": { description: "Paginated transactions list with staff attribution." }
        }
      }
    },
    "/api/central-ledger/staff": {
      get: {
        summary: "Staff List for Dropdown Filter",
        description: "Returns list of Admin and Staff accounts available for central ledger filtering.",
        security: [{ BearerAuth: [] }],
        responses: {
          "200": { description: "List of Admin and Staff users." }
        }
      }
    },
    "/api/central-ledger/staff-summary": {
      get: {
        summary: "Staff-Wise Operational & Financial Summary",
        description: "Calculates staff-wise breakdown of customer additions, gold items, loans created/closed, collections, and releases.",
        security: [{ BearerAuth: [] }],
        parameters: [
          { name: "staffId", in: "query", schema: { type: "string" } },
          { name: "fromDate", in: "query", schema: { type: "string", format: "date" } },
          { name: "toDate", in: "query", schema: { type: "string", format: "date" } }
        ],
        responses: {
          "200": { description: "Calculated staff-wise summary metrics." }
        }
      }
    },
    "/api/central-ledger/summary": {
      get: {
        summary: "Central Ledger KPI Overview",
        description: "Calculates global or staff-filtered KPI card metrics.",
        security: [{ BearerAuth: [] }],
        parameters: [
          { name: "staffId", in: "query", schema: { type: "string" } },
          { name: "fromDate", in: "query", schema: { type: "string", format: "date" } },
          { name: "toDate", in: "query", schema: { type: "string", format: "date" } }
        ],
        responses: {
          "200": { description: "KPI summary metrics." }
        }
      }
    },
    "/api/central-ledger/transactions/{id}": {
      get: {
        summary: "Transaction & Staff Attribution Details",
        security: [{ BearerAuth: [] }],
        parameters: [
          { name: "id", in: "path", required: true, schema: { type: "string" } }
        ],
        responses: {
          "200": { description: "Detailed transaction and staff attribution breakdown." },
          "404": { description: "Transaction not found." }
        }
      }
    }
  }
};

// Raw OpenAPI JSON Spec
router.get(['/swagger.json', '/openapi.json'], (req, res) => {
  res.json(openApiSpec);
});

// Interactive Swagger UI Page
router.get(['/', '/swagger', '/docs'], (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <title>Gold Pawn ERP - Swagger API Documentation</title>
      <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css" />
      <style>
        .swagger-ui .topbar { background-color: #0c101b; }
      </style>
    </head>
    <body style="margin:0; background: #fafafa;">
      <div id="swagger-ui"></div>
      <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
      <script>
        window.onload = () => {
          SwaggerUIBundle({
            url: '/api-docs/swagger.json',
            dom_id: '#swagger-ui',
          });
        };
      </script>
    </body>
    </html>
  `);
});

module.exports = router;
