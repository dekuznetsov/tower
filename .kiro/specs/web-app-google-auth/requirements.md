# Requirements Document — Web App, Google OAuth & Terraform Delivery

## Introduction

This document defines the requirements for delivering the hydroponics farm operator
interface as a **web application** (since iOS App Store publication is unavailable), hosted
on **Firebase Hosting**, authenticated with **Google OAuth**, and restricted to an
**allowlist** of authorized accounts. It further defines that all Firebase/GCP
infrastructure is provisioned as code with **Terraform**, and that the web build is
**deployed through Terraform**.

The web application is a new React + TypeScript client that reuses the existing Firebase
Realtime Database backend and firmware without modification. The existing Flutter codebase
(`mobile/`) is retained unchanged as the basis for future Android/iOS builds and is out of
scope for deployment here.

## Glossary

- **Web_App**: The new React + TypeScript single-page application (SPA) that replicates the
  operator dashboard in a browser.
- **Firebase_Hosting**: The Firebase service that serves the compiled Web_App static assets.
- **Firebase_Auth**: The Firebase Authentication (Identity Platform) service used to sign in
  operators.
- **Google_OAuth**: Sign-in via the Google identity provider through Firebase_Auth.
- **Allowlist**: The set of authorized user accounts permitted to read and control tower
  data, stored under the database path `/allowlist/{uid}` with value `true`.
- **RTDB**: The existing Firebase Realtime Database instance (`farms/farm_id_1/towers/tower_1`).
- **TowerState**: The client-side data model mirroring the RTDB tower schema.
- **TowerRepository**: The client-side module encapsulating all RTDB write operations.
- **Identity_Platform**: The Google Cloud Identity Platform backing Firebase_Auth, configured
  via Terraform to enable the Google sign-in provider.
- **Terraform**: The infrastructure-as-code tool used to provision the GCP/Firebase project
  and all Firebase resources, and to drive web deployment.
- **Firmware**: The existing ESP32 firmware, which authenticates with a privileged credential
  (legacy database secret / service-account token) and therefore bypasses user-facing
  security rules. Out of scope for change.
- **Web_Config**: The Firebase web SDK configuration (apiKey, appId, messagingSenderId,
  projectId, databaseURL, authDomain) required to initialize the Web_App.

---

## Requirements

### Requirement 1: Web Application Shell & Firebase Initialization

**User Story:** As a farm operator, I want a browser-based app that connects to Firebase, so
that I can monitor and control towers without an iOS/Android app.

#### Acceptance Criteria

1. THE Web_App SHALL be a React + TypeScript single-page application built with a static
   bundler (Vite) producing output suitable for Firebase_Hosting.
2. WHEN the Web_App loads, THE Web_App SHALL initialize the Firebase web SDK using Web_Config
   values supplied via build-time environment variables, not hard-coded secrets.
3. THE Web_App SHALL initialize the Firebase_Auth and RTDB SDK clients from a single shared
   initialization module.

---

### Requirement 2: Google OAuth Authentication

**User Story:** As a farm operator, I want to sign in with my Google account, so that access
is secured without managing a separate password.

#### Acceptance Criteria

1. WHEN an unauthenticated user opens the Web_App, THE Web_App SHALL display a sign-in screen
   offering Google_OAuth sign-in.
2. WHEN the user initiates sign-in, THE Web_App SHALL authenticate via Firebase_Auth using the
   Google provider (`signInWithPopup`, with `signInWithRedirect` as fallback).
3. WHILE a user is authenticated, THE Web_App SHALL expose the current user's identity (uid,
   email) to the application through an auth context.
4. WHEN the user signs out, THE Web_App SHALL clear the session and return to the sign-in
   screen.
5. WHEN an authentication error occurs, THE Web_App SHALL display an error message and remain
   on the sign-in screen without crashing.

---

### Requirement 3: Allowlist Authorization (Client Gate)

**User Story:** As a farm owner, I want only approved accounts to control the pump, so that a
stranger with a Google account cannot operate my equipment.

#### Acceptance Criteria

1. WHEN a user completes Google_OAuth sign-in, THE Web_App SHALL check the user's membership in
   the Allowlist by reading `/allowlist/{uid}`.
2. IF the authenticated user is not present in the Allowlist, THEN THE Web_App SHALL display an
   "access denied" state and SHALL NOT display tower data or controls.
3. IF the authenticated user is present in the Allowlist, THEN THE Web_App SHALL display the
   tower dashboard.
4. THE Web_App SHALL treat the client-side Allowlist check as UX only; authoritative
   enforcement SHALL be performed by the security rules (Requirement 7).

---

### Requirement 4: Realtime Tower Data (Read)

**User Story:** As a farm operator, I want live tower data in the browser, so that readings and
state update automatically.

#### Acceptance Criteria

1. WHEN the dashboard is displayed, THE Web_App SHALL subscribe to the RTDB path
   `farms/farm_id_1/towers/tower_1` and map each snapshot to a TowerState.
2. WHEN the RTDB emits an updated value, THE Web_App SHALL re-render the affected UI without a
   manual refresh.
3. THE Web_App SHALL parse tower snapshots using null-coalescing defaults for every field so
   partial data never crashes the app.
4. THE Web_App SHALL track connection status via `.info/connected` and expose it to the UI.

---

### Requirement 5: Tower Control (Write)

**User Story:** As a farm operator, I want to change mode, pump switch, speed, and intervals
from the browser, so that I can control the tower remotely.

#### Acceptance Criteria

1. WHEN the operator toggles the mode, THE TowerRepository SHALL write `pump_mode`
   (`'auto'` | `'manual'`).
2. WHEN the operator toggles the manual switch, THE TowerRepository SHALL write `pump_switch`.
3. WHEN the operator changes the speed slider, THE TowerRepository SHALL write `pump_speed` as
   an integer in the range 0–255.
4. WHEN the operator saves intervals, THE TowerRepository SHALL write `interval_on_min` and
   `interval_off_min` in a single atomic `update`.
5. THE Web_App SHALL never write `pump_state`, `moisture`, or `water_level_low` (firmware-owned
   fields).

---

### Requirement 6: UI Parity With the Flutter Dashboard

**User Story:** As a farm operator, I want the web dashboard to behave like the existing app,
so that no functionality is lost.

#### Acceptance Criteria

1. THE Web_App SHALL display a connection banner when disconnected from RTDB.
2. THE Web_App SHALL display a sensor card showing `moisture` and a water-level status of
   `'Good'` or `'Low'`.
3. THE Web_App SHALL display the Auto mode panel (interval fields) if and only if
   `pump_mode == 'auto'`, and the Manual mode panel (switch + speed slider) if and only if
   `pump_mode == 'manual'`.
4. THE Web_App SHALL map the speed slider 0–100% to `pump_speed` 0–255, clamped and monotonic.
5. THE Web_App SHALL reject interval input that is not a positive integer and SHALL NOT perform
   an RTDB write for invalid input.

---

### Requirement 7: Security Rules — Allowlist Enforcement

**User Story:** As a farm owner, I want the database itself to block unauthorized users, so
that security does not depend on the client.

#### Acceptance Criteria

1. THE RTDB security rules SHALL grant read and write on the `farms/` path only when
   `auth != null` AND `/allowlist/{auth.uid}` equals `true`.
2. THE RTDB security rules SHALL deny write access to the `/allowlist` path from all
   client identities (managed out-of-band only).
3. THE RTDB security rules SHALL deny all access to paths outside `farms/` and `allowlist/`.
4. THE security rules SHALL remain compatible with the Firmware's privileged credential so
   that sensor and `pump_state` writes continue to function.

---

### Requirement 8: Terraform Infrastructure Provisioning

**User Story:** As an operator/maintainer, I want all cloud infrastructure defined as code, so
that the environment is reproducible and reviewable.

#### Acceptance Criteria

1. THE Terraform configuration SHALL provision (or adopt) a GCP project and enable Firebase on
   it, including required service APIs.
2. THE Terraform configuration SHALL provision the RTDB instance, a Firebase web app, the
   Identity_Platform configuration with the Google sign-in provider enabled, and a
   Firebase_Hosting site.
3. THE Terraform configuration SHALL accept the Google OAuth client ID and secret as input
   variables (marked sensitive) for enabling Google sign-in, since these originate from the
   GCP OAuth consent screen.
4. THE Terraform configuration SHALL store its state in a remote backend (GCS) with locking.
5. THE Terraform configuration SHALL be parameterized (project id, region, billing account,
   Hosting site id, authorized domains) via variables with no secrets committed to the repo.

---

### Requirement 9: Terraform-Driven Configuration Wiring

**User Story:** As a developer, I want Terraform to output the web SDK config, so that the web
build is wired to the provisioned project without manual copying.

#### Acceptance Criteria

1. THE Terraform configuration SHALL output the Web_Config values for the provisioned Firebase
   web app.
2. THE build process SHALL consume those outputs to produce the Web_App environment
   configuration (e.g., a generated `.env` consumed by Vite), without committing secrets.
3. THE Terraform configuration SHALL output the Hosting site default domain and the RTDB
   database URL.

---

### Requirement 10: Web Deployment via Terraform

**User Story:** As a maintainer, I want `terraform apply` to publish the web build, so that
deployment is part of the same IaC workflow.

#### Acceptance Criteria

1. THE Terraform workflow SHALL deploy the compiled Web_App to Firebase_Hosting as part of the
   apply, using a hosting release (or a Terraform-invoked Firebase CLI step where the native
   provider cannot upload files).
2. WHEN the web assets change, re-running the Terraform deploy SHALL publish a new Hosting
   release serving the updated assets.
3. THE deployment step SHALL depend on the Hosting site and project resources so ordering is
   correct.

---

### Requirement 11: Rules, Seed & Allowlist Deployment

**User Story:** As a maintainer, I want database rules, seed data, and the initial allowlist
applied through the IaC workflow, so that a fresh environment is fully usable.

#### Acceptance Criteria

1. THE workflow SHALL deploy the RTDB security rules (Requirement 7) via the Firebase CLI/REST
   invoked from Terraform, since RTDB rules are not a native Terraform resource.
2. THE workflow SHALL seed the initial tower structure from `firebase/seed_data.json`.
3. THE workflow SHALL seed the initial Allowlist entries from a Terraform input variable
   (list of authorized uids/emails) using a privileged credential.
4. THE Allowlist seeding SHALL be idempotent (re-running does not duplicate or corrupt data).

---

### Requirement 12: Testing

**User Story:** As a developer, I want the web client's logic verified, so that ported behavior
matches the original spec.

#### Acceptance Criteria

1. THE Web_App SHALL include unit and property-based tests (Vitest + fast-check, ≥100
   iterations) for TowerState serialization, water-level display, slider mapping, mode/panel
   visibility, and interval validation.
2. THE Web_App tests SHALL be tagged in the format
   `// Feature: web-app-google-auth, Property N: <name>`.
3. THE Terraform configuration SHALL pass `terraform validate` and `terraform fmt -check` in
   CI.

---

### Requirement 13: Documentation & Secret Hygiene

**User Story:** As a maintainer, I want clear docs and no leaked secrets, so that the project
stays secure and onboardable.

#### Acceptance Criteria

1. THE repository SHALL document the provisioning and deployment procedure (prerequisites,
   variables, apply steps).
2. THE repository SHALL NOT commit OAuth secrets, service-account keys, Terraform state, or
   generated `.env` files (enforced via `.gitignore`).
3. THE `CLAUDE.md` and Kiro specs SHALL be updated to describe the web client and access model.
