-- Create schemas for modular monolith
CREATE SCHEMA IF NOT EXISTS users;
CREATE SCHEMA IF NOT EXISTS betting;
CREATE SCHEMA IF NOT EXISTS payments;
CREATE SCHEMA IF NOT EXISTS odds;
CREATE SCHEMA IF NOT EXISTS notifications;

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
