const express = require('express');
const router = express.Router();

const openApiSpec = {
  openapi: "3.0.0",
  info: {
    title: "Gold & Silver Pawn Loan Management ERP API",
    version: "1.0.0",
    description: "Complete Node.js Express REST API for Gold & Silver Pawn Management ERP system with Two-Step Gmail OTP Authentication."
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
    "/api/auth/me": {
      get: {
        summary: "Retrieve Authenticated User Profile",
        security: [{ BearerAuth: [] }],
        responses: {
          "200": { description: "Authenticated user details and permission codes." },
          "401": { description: "Unauthorized access token." }
        }
      }
    },
    "/api/auth/refresh-token": {
      post: {
        summary: "Refresh Access Token",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                properties: {
                  refreshToken: { type: "string", example: "eyJhbGciOiJIUzI1Ni..." }
                },
                required: ["refreshToken"]
              }
            }
          }
        },
        responses: {
          "200": { description: "Fresh access token issued." },
          "401": { description: "Invalid or expired refresh token." }
        }
      }
    },
    "/api/auth/logout": {
      post: {
        summary: "Logout Admin Session",
        responses: {
          "200": { description: "Logged out successfully." }
        }
      }
    },
    "/customers/create": {
      post: {
        summary: "Create Customer",
        security: [{ BearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                properties: {
                  name: { type: "string", example: "Ramesh Kumar" },
                  mobile: { type: "string", example: "9876543210" },
                  address: { type: "string", example: "123 Main Market Street" }
                },
                required: ["name", "mobile", "address"]
              }
            }
          }
        },
        responses: {
          "201": { description: "Customer created successfully." }
        }
      }
    },
    "/loans/close": {
      post: {
        summary: "Final Settlement & Loan Closure",
        security: [{ BearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                properties: {
                  loan_id: { type: "integer", example: 1 },
                  manual_final_interest: { type: "number", example: 100 },
                  payment_amount: { type: "number", example: 5100 },
                  payment_mode: { type: "string", example: "CASH" }
                },
                required: ["loan_id"]
              }
            }
          }
        },
        responses: {
          "200": { description: "Settlement payment recorded successfully." }
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
