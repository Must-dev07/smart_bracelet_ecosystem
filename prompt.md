# PROJECT-WIDE REVIEW, CONSISTENCY FIXES AND TERMINOLOGY UPDATE

You are working directly inside the current project folder.

Your task is to **review the entire existing project before making changes**, understand how the frontend, mobile application, backend, database, authentication, APIs, dashboard, and bracelet/cinture tracking logic currently work, and then implement the changes below.

## IMPORTANT WORKING RULES

1. **Do NOT ask me unnecessary questions.**

   * The project is already open in your current working directory.
   * Inspect the existing code, configuration, database schema, documentation, routes, components, services, and APIs yourself.
   * Only ask a question if a genuinely blocking business decision cannot be determined from the existing project.

2. **Do NOT rebuild the project from scratch.**

   * Preserve the existing architecture where it is coherent.
   * Modify existing functionality instead of creating duplicate implementations.
   * Reuse existing components, services, models, APIs, authentication mechanisms, and database structures whenever possible.

3. **Do NOT perform unnecessary refactoring.**

   * Avoid changing working code simply because you would personally structure it differently.
   * Only refactor code when it is necessary for one of the requested changes, to fix an actual bug, or to resolve an architectural inconsistency.

4. **Do not spend tokens explaining obvious things.**

   * Inspect → identify → implement → test → report.
   * Keep explanations concise.
   * Focus your effort on the actual project.

5. **After every significant modification, verify that it does not break existing functionality.**

6. **Do not silently invent business rules.**

   * If an existing implementation conflicts with the requirements below, prioritize these requirements.
   * If an important conflict cannot be resolved safely from the existing project, document it in the tracking report.

---

# 1. FIRST: COMPLETE PROJECT AUDIT

Before modifying code, inspect the whole project.

Identify at minimum:

* Backend framework and structure
* Frontend/dashboard structure
* Mobile application structure
* Database schema/entities
* Authentication and authorization
* User roles
* Doctor management
* Admin management
* Parent management
* Baby/child management
* Bracelet/cinture management
* Health monitoring/tracking logic
* Assignment logic
* Alerts/notifications
* Dashboard statistics
* Mobile monitoring screens
* API endpoints
* DTOs/request/response models
* Database relationships
* Existing terminology
* Existing tests
* Existing documentation

Pay particular attention to how the following currently interact:

`Admin → Doctor → Parent → Baby → Cinture → Tracking → Alerts → Dashboard/Mobile`

Do not modify anything during this initial inspection unless necessary to understand the code.

---

# 2. IMPORTANT BUSINESS RULE CHANGE: PARENTS CANNOT ADD BABIES

Change the existing system so that:

## Parents MUST NOT be able to create/add/register a baby.

Remove or disable the parent-side functionality that allows a parent to directly create a baby.

This restriction must exist at **both frontend and backend levels**.

### Frontend

Parents should no longer see:

* "Add baby"
* "Create baby"
* "Register baby"
* equivalent buttons/actions/forms

in their interface.

Do not rely only on hiding the button.

### Backend

The backend must also reject unauthorized baby creation requests from parents.

A malicious/API client must not be able to bypass the UI and create a baby using a parent account.

Implement proper authorization based on the project's existing authentication/role system.

---

# 3. NEW BABY REGISTRATION / TRACKING WORKFLOW

The intended workflow is:

### Step 1 — Baby is born

When a newborn requires monitoring because the baby is not in a normal/healthy state or requires medical surveillance, the baby is registered in the system.

### Step 2 — Baby is registered by authorized medical/admin personnel

Only:

* Doctor
* Admin

can add/register the baby.

Parents cannot perform this operation.

### Step 3 — Baby enters the tracking system

Once registered, the baby can be associated with the monitoring system/cinture.

The system should support the concept that the baby is now under medical monitoring.

### Step 4 — Doctor assignment

A doctor must be assigned to the baby.

The doctor can be:

* assigned by an Admin
* or assigned/accepted through the existing project's "volunteer doctor" mechanism if such functionality already exists

Inspect the existing implementation before modifying this part.

Do not create a completely new volunteer system if one already exists.

### Step 5 — Monitoring

Once the baby and cinture are properly associated, the monitoring system can receive and display the baby's health information.

---

# 4. VERIFY THE ENTIRE AUTHORIZATION MODEL

Review all role permissions related to:

* Admin
* Doctor
* Parent
* Baby
* Cinture
* Monitoring
* Alerts

Make sure authorization is coherent between:

* frontend
* mobile application
* backend
* database

Do not rely exclusively on frontend restrictions.

If you find authorization vulnerabilities or inconsistencies related to the requested workflow, fix them.

---

# 5. GLOBAL TERMINOLOGY CHANGE

The project terminology must change.

Replace the concept/name:

**"bracelet"**

with:

**"cinture"**

This must be applied consistently throughout the project.

Search the entire project for variants such as:

* bracelet
* Bracelet
* BRACELET
* bracelets
* Bracelets
* bracelet-related variable names
* component names
* API names
* labels
* database-related names where safe
* documentation
* comments
* UI text

Use the appropriate French/English grammatical form where necessary, but the project's new concept must be **cinture**.

IMPORTANT:

Do not blindly rename database columns/tables or API contracts if doing so would break the existing application.

If a database/API migration is required, implement it properly.

If an internal technical identifier can safely be renamed, rename it.

The final user-facing application must consistently use **cinture**, not bracelet.

---

# 6. HEALTH METRIC TERMINOLOGY CHANGE

Replace:

**SpO2**

with:

**respiration**

The application should no longer present SpO2 as the user-facing health metric.

Search for:

* SpO2
* SPO2
* spo2
* oxygen saturation
* saturation oxygen
* related UI labels
* related dashboard labels
* mobile labels
* API DTO names
* frontend state variables
* database fields

Determine whether the existing value is actually an oxygen saturation measurement.

IMPORTANT:

Do not falsely reinterpret a physical sensor value.

If the underlying hardware/data model currently measures SpO2, determine how the existing system represents it and adapt the application's domain/UI terminology to the requested "respiration" concept without corrupting the actual data.

If the backend and hardware contract make this change technically significant, document the issue in the tracking report.

---

# 7. REMOVE "MOUVEMENT" COMPLETELY

The movement metric/functionality must be removed from the project.

Search globally for:

* mouvement
* movement
* motion
* movement-related fields
* movement-related API endpoints
* movement-related DTO fields
* movement-related frontend components
* movement-related mobile components
* movement-related dashboard cards
* movement-related charts
* movement-related alerts

Remove it from the actual application where appropriate.

Do not leave dead UI elements or unused movement functionality behind.

However, do not remove unrelated motion/technical infrastructure if it is required internally by another feature. Distinguish between the health metric "movement" and unrelated technical code.

---

# 8. REAL-WORLD UI/UX IMPROVEMENT

The current UI must be upgraded to look like a **real medical monitoring application**, not a prototype/demo.

## Remove all emojis from the application UI

Search all frontend/mobile interfaces for emojis and remove them.

Do not replace emojis with other decorative emojis.

Use proper:

* icons
* typography
* spacing
* cards
* buttons
* status indicators
* visual hierarchy

where appropriate.

## General UI requirements

Improve:

* spacing
* alignment
* typography
* hierarchy
* buttons
* forms
* cards
* tables
* navigation
* dashboards
* empty states
* loading states
* error states
* status indicators
* responsive behavior
* mobile usability
* accessibility

The UI should communicate:

* medical monitoring
* reliability
* clarity
* safety
* professionalism

Avoid excessive decoration.

Do not create a flashy "startup landing page" aesthetic.

The interface should look appropriate for a real healthcare/monitoring product.

---

# 9. DASHBOARD ↔ MOBILE APP CONSISTENCY

There is currently an inconsistency between the dashboard and the mobile application.

Find it.

Do not assume what the inconsistency is.

Inspect both applications and compare:

* terminology
* baby information
* doctor assignment
* monitoring state
* cinture association
* health measurements
* respiration
* alerts
* statuses
* timestamps
* authentication/roles
* available actions
* API data
* empty states
* error states

Determine the actual source of truth.

Then fix the inconsistency so that both applications represent the **same backend/domain state**.

IMPORTANT:

Do not solve synchronization problems by duplicating data manually in frontend code.

The backend/API/database should remain the source of truth where appropriate.

If the dashboard and mobile application interpret the same API response differently, fix the responsible layer.

---

# 10. BACKEND COHERENCE AUDIT

After understanding the requested changes, perform a backend consistency review.

Check:

* entities
* relationships
* repositories
* services
* controllers
* DTOs
* validation
* authorization
* role checks
* database constraints
* foreign keys
* nullability
* cascade behavior
* assignment relationships
* API response consistency
* error handling
* authentication
* baby lifecycle
* doctor assignment
* cinture association
* monitoring data

Look specifically for contradictions such as:

* Parent can create baby in one endpoint but not another.
* Doctor assignment exists in the frontend but not correctly in the backend.
* A baby can enter monitoring without a doctor when the business workflow requires one.
* A cinture can be assigned to multiple babies incorrectly.
* Dashboard and mobile use different APIs or incompatible DTOs.
* Deleted entities leave invalid relationships.
* Role checks exist in frontend but not backend.
* Database relationships do not reflect actual business rules.

---

# 11. REPORT EVERY REAL ISSUE FOUND

If you find backend, database, API, frontend, mobile, or architectural issues during this review:

* Fix issues that are clearly related to the requested changes.
* Do not randomly redesign unrelated parts of the system.
* Record every important issue you discover.

For issues that are outside the requested scope and risky to change, record:

* what the issue is
* where it exists
* why it is a problem
* severity
* whether it was fixed
* recommended future action

---

# 12. CREATE / MAINTAIN A PROJECT TRACKING FILE

Create or update a root-level file:

`PROJECT_TRACKING.md`

This file is extremely important.

Its purpose is to prevent future coding sessions from wasting tokens rediscovering what has already been done.

The file must contain at least:

## Project status

* Current architecture
* Main applications
* Backend
* Database
* Dashboard
* Mobile app

## Requirements

List the current business requirements.

## Completed

Every completed change with a concise description.

## In progress

Current unfinished work.

## Remaining

Things still requiring implementation.

## Known issues

Real issues discovered during the audit.

## Decisions

Important business/technical decisions already made.

## Verification

For each major feature:

* implemented
* tested
* verified
* not verified

## Last work performed

Record:

* date
* changes made
* files/components affected
* tests performed
* remaining concerns

Keep this file concise and factual.

Before starting future work, read `PROJECT_TRACKING.md`.

After completing work, update it.

---

# 13. TESTING AND VERIFICATION

After implementation, test the affected functionality.

At minimum verify:

### Parent

* Cannot see baby creation functionality.
* Cannot create baby through the API.
* Can still access legitimate parent functionality.

### Doctor

* Can add/register a baby if permitted by the existing authorization model.
* Can access babies assigned to them.
* Can access monitoring information according to the existing business rules.

### Admin

* Can register/add babies.
* Can assign doctors.
* Can manage the monitoring workflow.

### Cinture

* New terminology appears correctly.
* Association with the baby works.
* No unintended bracelet terminology remains in user-facing UI.

### Health monitoring

* Respiration is displayed correctly.
* SpO2 is not incorrectly displayed as a separate user-facing metric.
* Movement is removed.

### Dashboard

* Correct baby information.
* Correct doctor assignment.
* Correct monitoring status.
* Correct health data.
* Correct alerts.

### Mobile

* Same underlying information as dashboard.
* Same terminology.
* Same monitoring state.
* Same assignment state.

### Security

Attempt to verify that frontend restrictions cannot be bypassed through direct API calls.

---

# 14. SEARCH FOR LEFTOVERS

Before declaring the task complete, perform a project-wide search for:

`bracelet`

`SpO2`

`spO2`

`movement`

`mouvement`

and related obsolete terminology.

Classify every remaining occurrence:

* legitimate technical/hardware reference
* migration/compatibility code
* documentation that needs updating
* obsolete occurrence that must be removed

Do not simply report zero matches if legitimate technical references must remain.

---

# 15. FINAL RESPONSE

When finished, provide a concise report containing:

1. What was changed.
2. What was fixed.
3. Backend issues found and fixed.
4. Dashboard/mobile inconsistencies found and fixed.
5. Database changes, if any.
6. Tests performed.
7. Remaining issues.
8. Anything that could not safely be changed and why.
9. Location of `PROJECT_TRACKING.md`.

Do not give a long explanation of code that was already inspected.

The objective is a **coherent, production-oriented medical monitoring application**, not a superficial text replacement.

## FINAL PRIORITY ORDER

When making decisions, use this order:

1. Business requirements in this document
2. Security and authorization
3. Data integrity
4. Backend/domain consistency
5. Dashboard/mobile consistency
6. Correct functionality
7. Professional UI/UX
8. Code cleanliness
9. Cosmetic improvements

Do not sacrifice data integrity or security for cosmetic changes.
