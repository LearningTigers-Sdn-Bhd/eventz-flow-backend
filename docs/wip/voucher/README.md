# Voucher Module (Archived)

This directory contains documentation for the voucher module that has been removed from the codebase.

## Status

**REMOVED** - These features have been removed and replaced with the visitor stamp system for non-ticket events.

## Archived Features

- **Voucher Management** - CRUD operations for vouchers
- **Public Voucher Claims** - Ticket-based voucher claiming system
- **Vendor User Vouchers** - Dashboard for viewing voucher claims
- **Voucher Analytics** - Analytics for voucher engagement, claims, and redemptions

## Replacement

The voucher system has been replaced with:
- **Visitor System** - Event-scoped visitor records with `public_id` for non-ticket events
- **Visitor Vendor Stamps** - Stamp tracking system when vendors scan visitor `public_id`
- **Stamp Analytics** - Analytics based on stamp counts

## Migration Notes

- Voucher tables (`vouchers`, `user_vouchers`) have been removed from the database
- `UserEngageVendor` has been renamed to `VisitorVendorStamp`
- Visitor model now has `public_id` and is event-scoped (not vendor-scoped)
- Public voucher endpoints have been removed
- Event interactive endpoints have been removed

## Documentation Files

- `voucher-management.md` - Voucher CRUD operations
- `user-voucher-public.md` - Public voucher claim API
- `vendor-user-vouchers.md` - Vendor dashboard for voucher claims
- `voucher-analytics.md` - Voucher analytics endpoints
