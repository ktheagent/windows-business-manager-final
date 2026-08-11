# Airmonlink Business Manager — User Guide

**Product:** Airmonlink Business Manager  
**Release:** 1.3.0 Build 9  
**Platform:** Windows 10 / Windows 11 (64-bit)  
**Operation:** Offline-first business management and point of sale

This manual is for business owners, managers, cashiers, accountants, stock officers, and other authorised staff.

> **Protect your data:** Create regular backups. Keep at least one backup on a different device or secure remote location.

---

## 1. Getting Started

Airmonlink Business Manager combines point of sale, inventory, customers, suppliers, commercial documents, purchases, expenses, cash control, staff permissions, reports, printing, backup, and licensing in one Windows application.

### First launch

1. Install and open Airmonlink Business Manager.
2. Activate the software if a valid licence has not already been activated.
3. Enter or confirm your business information.
4. Create the owner/administrator account and PIN where required.
5. Review business settings before entering live transactions.
6. Add products, customers, suppliers, registers, and staff as needed.
7. Create a backup after initial setup.

### Recommended setup order

1. Business details
2. Branches
3. Staff and permissions
4. Cash registers
5. Products and opening stock
6. Customers
7. Suppliers
8. Printer settings
9. Email settings if used
10. Backup location
11. Test sale and test print

---

## 2. Business Setup

Open the business/settings area and enter the details that should appear on business records and documents.

Typical information includes:

- Business or organisation name
- Address
- Telephone number
- Email address
- Tax or registration information where applicable
- Logo/branding where supported
- Default branch
- Receipt and document settings

Review the information before issuing invoices, quotations, receipts, or statements to customers.

---

## 3. Dashboard

The dashboard gives an overview of business activity using data stored in Airmonlink.

Depending on your role and available records, the dashboard may show information such as:

- Sales activity
- Stock information
- Customer balances
- Supplier balances
- Profit information
- Low-stock conditions
- Business-health indicators
- Operational recommendations

Dashboard figures depend on the transactions entered into the system. If data appears incorrect, review the underlying sales, purchases, expenses, stock, payments, and returns.

---

## 4. Staff Accounts and Permissions

Airmonlink supports role-based access.

Available staff roles include:

- Owner
- Manager
- Cashier
- Accountant
- Stock Officer

### Create a staff account

1. Open the staff/users area.
2. Choose to add a new staff member.
3. Enter the staff member's name and required details.
4. Select the correct role.
5. Set the staff PIN where required.
6. Review permissions.
7. Save.

### Security recommendations

- Give each person their own account.
- Do not share owner credentials.
- Use different PINs for different staff members.
- Give staff only the permissions required for their work.
- Disable accounts for staff who leave the business.
- Review audit and login information if suspicious activity occurs.

Failed login and session information may be recorded by the application.

---

## 5. Products and Inventory

Products are the foundation of stock and sales operations.

### Add a product

1. Open Products/Inventory.
2. Choose **New Product** or the equivalent action.
3. Enter the product name.
4. Enter SKU if used.
5. Enter or scan the barcode if used.
6. Select a category where applicable.
7. Enter cost price.
8. Enter selling price.
9. Enter opening/current stock where appropriate.
10. Set the low-stock/reorder level.
11. Save.

### Stock adjustments

Use Stock Adjustment when stock must be increased or decreased outside a normal sale, purchase receipt, return, or transfer.

1. Open Stock Adjustment.
3. Explicitly select the product.
3. Choose increase or decrease.
4. Enter the quantity.
5. Enter the reason.
6. Confirm the adjustment.

Always enter a meaningful reason so future reviews are easier.

### Physical stock count

1. Open Physical Count/Stock Count.

2. Select the product.
3. Count the physical quantity.
4. Enter the quantity actually counted.
5. Compare physical quantity with system quantity.
6. Confirm the count/adjustment as required.

Do not enter the expected system quantity unless that is what was physically counted.

### Batches and expiry

Where batch/expiry functions are used, record the correct batch and expiry information when receiving or maintaining stock.

### Low stock

Set sensible reorder levels so low-stock reports can identify items that need replenishment.

---

## 6. Barcode Scanners

Airmonlink supports standard USB keyboard/HID barcode scanners for barcode entry and search.

### Basic setup

1. Connect the scanner to Windows.
2. Confirm Windows recognises it.
3. Open a barcode or product-search field in Airmonlink.
4. Place the cursor in the field.
5. Scan a barcode.

Most keyboard/HID scanners type the barcode into the active field and send Enter automatically.

### If a scanner does not work

- Test it in Notepad.
- Confirm the scanner types the expected barcode.
- Confirm the correct input field is active.
- Check that the product has the same barcode saved in Airmonlink.
- Review the scanner's own configuration manual.

---

## 7. Point of Sale

Use Point of Sale for normal checkout.

### Make a sale

1. Open **Point of Sale**.
2. If the customer is paying cash, make sure an appropriate cash shift is open.
3. Search for a product by name, SKU, or barcode, or scan it.
4. Select the product.
5. Enter the required quantity.
6. Add additional items.
7. Select the customer if needed.
8. Apply only authorised discounts.
9. Select the payment method.
10. Review quantities, prices, discounts, and total.
11. Complete the sale.
12. Print or save the receipt if required.

Completed stock-affecting sales update inventory.

### Credit sales

If your business allows customer credit:

1. Select the customer.
3. Confirm the customer's credit information/limit.
3. Complete the credit transaction according to your permissions.
4. Record later payments against the customer's account.

### Reprint a receipt

1. Find the saved/completed sale.
2. Open the sale details.
3. Choose receipt reprint/print.
4. Preview where available.
5. Select the correct printer.

---

## 8. Cash Registers and Shifts

Cash sales should be controlled through an active register shift.

### Create a register

1. Open Cash Registers.
3. Add a register.
3. Give it a clear name, for example **Front Till**.
4. Save.

### Open a shift

1. Open Cash Shifts.
2. Select the correct register.
3. Enter the opening float.
4. Confirm/open the shift.

### During the shift

Record supported cash movements accurately. Do not use stock or expense adjustments to hide cash differences.

### Close a shift

1. Open the active shift.
3. Count the physical cash.
3. Enter the actual closing amount.
4. Review the expected amount.
5. Review any variance.
6. Confirm the close.

Investigate unexplained variances.

---

## 9. Customers and Customer Credit

### Add a customer

1. Open Customers.
2. Choose Add Customer.
3. Enter the customer's details.
4. Set credit information if your business uses credit.
5. Save.

### Customer balances

Customer balances can reflect invoices, credit sales, part payments, and other supported account transactions.

### Customer payment

1. Open the customer's account or payment workflow.
3. Select the customer explicitly.
3. Enter the payment amount.
4. Select the payment method.
5. Reference the appropriate invoice/account entry where required.
6. Confirm the payment.
7. Issue or print a record if required.

### Customer statement

Generate a customer statement to show supported account activity and balance information.

---

## 10. Suppliers

Use Supplier Management for businesses and individuals that supply stock or services.

### Add a supplier

1. Open Suppliers.
2. Choose Add Supplier.
3. Enter name and contact information.
4. Save.

Supplier records are used in purchasing, goods receiving, deposits, part payments, and supplier debt reporting.

---

## 11. Purchase Orders and Goods Receiving

### Create a purchase order

1. Open Purchase Orders.
2. Create a new purchase order.
3. Explicitly select the supplier.
4. Add the products being ordered.
5. Enter quantities and prices.
6. Review totals.
7. Save the purchase order.
8. Print/export where required.

### Receive goods

1. Open the relevant purchase order/goods receipt workflow.
3. Confirm the supplier/order.
3. Enter the quantities actually received.
4. Record partial receipt where only part of the order arrived.
5. Confirm the receipt.
6. Verify stock quantities after posting.

Do not mark unreceived stock as received.

### Supplier deposits and part payments

Use supplier payment/deposit workflows to record money paid before or after goods receipt. Enter the actual amount paid and keep references where appropriate.

---

## 12. Quotations, Estimates, Pro-forma Invoices and Invoices

Airmonlink supports professional commercial documents.

Supported document types include:

- Quotations
- Estimates
- Pro-forma invoices
- Invoices
- Delivery notes
- Credit notes

### Create a document

1. Open the Commercial/Documents area.
2. Choose the document type.
3. Create a new document.
4. Select the customer if required.
5. Add products explicitly, or add manual service lines where appropriate.
6. Enter quantity and price.
7. Apply permitted discount/tax information where applicable.
8. Review totals.
9. Save.
10. Preview/print/export the PDF as required.

New documents start empty. The application should not silently insert the first product in inventory.

### Product versus service lines

- Use product lines for inventory products.
- Use manual/service lines for services or non-stock charges.

### Convert a quotation

Where conversion is available:

1. Open the saved quotation.
2. Choose the supported conversion action.
3. Review the generated invoice/sale.
4. Confirm before posting.

Avoid repeatedly converting the same quotation.

---

## 13. Delivery Notes and Credit Notes

### Delivery note

Use delivery notes to document goods delivered to a customer.

1. Open Commercial Documents.
2. Choose Delivery Note.
3. Select the customer.
4. Add the relevant items.
5. Confirm quantities.
6. Save.
7. Print or share.

### Credit note

Use credit notes for supported customer credit adjustments.

Enter the correct customer, related items/amounts, and reason before saving.

---

## 14. Returns and Refunds

Returns are tied to explicit sale and item selection.

### Process a return

1. Open Returns/Refunds.
2. Select the original sale.
3. Select the item being returned.
4. Enter the return quantity.
5. Enter the reason.
6. Choose the refund method.
7. Choose whether returned stock should be restocked.
8. Review the transaction.
9. Confirm.

### Partial return

Enter only the quantity actually returned.

### Restocking

Restock only goods that are physically back in usable inventory.

---

## 15. Expenses

Use Expenses to record operating costs.

### Record an expense

1. Open Expenses.
3. Add a new expense.
3. Enter the date, amount, category/details, and payment information.
4. Select the relevant cash session where required.
5. Save.

### Recurring expenses

Use recurring-expense functions for costs that repeat. Review generated dates, especially around month-end.

Accurate expense entry improves profit and business-health reporting.

---

## 16. Multi-Branch Operations

If your business uses multiple branches, keep branch selection accurate.

Branch-aware functions may include:

- Separate branch inventory
- Branch-level transactions
- Branch profitability
- Stock transfers
- Consolidated owner information

Always confirm the active/source/destination branch before posting inventory movements.

---

## 17. Stock Transfers

### Create a transfer

1. Open Stock Transfers.
2. Select the source branch.
3. Select the destination branch.
4. Add the products and quantities.
5. Review.
6. Dispatch the transfer.
7. Receive/confirm it at the destination according to the workflow.

Use dispatch and receipt actions rather than manually adjusting both branches.

---

## 18. Reports and Business Health

Reports are based on recorded business transactions.

Available reporting areas include supported information such as:

- Sales
- Profit
- Product profitability
- Branch profitability
- Customer debt
- Supplier debt
- Low stock
- Inventory information
- Business-health metrics
- Data-derived recommendations

If a report looks wrong:

1. Check the report date range.
3. Check the selected branch.
3. Review source transactions.
4. Confirm purchases, expenses, returns, and payments were posted correctly.

---

## 19. Printing, Receipts and PDF Documents

Airmonlink includes Windows printing and PDF generation.

### Receipt printing

1. Complete or open the relevant sale.
2. Choose Print Receipt.
3. Preview if available.
4. Select the correct Windows printer.
5. Confirm the receipt/paper size.
6. Print.

### Print preview

Use preview to check content before printing.

### Printer test page

1. Open Business Settings/Printing.
2. Choose Printer Test Page.
3. Select the printer.
4. Print.
5. Verify text, alignment, and paper handling.

### Report/document sizes

Supported document output may include sizes such as:

- A4
- A5
- Letter
- Receipt/thermal layouts

### Blank or incorrect printout

1. Preview the document first.
2. Run the printer test page.
3. Confirm the correct printer.
4. Confirm paper size.
5. Confirm the Windows printer works outside Airmonlink.
6. Check printer drivers and paper.
7. Reopen Airmonlink after installing a new printer driver if needed.

Generated PDFs are validated by the application before use where supported.

---

## 20. Email and WhatsApp Sharing

### Email

If SMTP is configured, supported documents may be sent by email.

1. Configure SMTP settings in the appropriate settings area.
2. Test configuration where available.
3. Open the supported document.
4. Choose Email/Send.
5. Confirm the recipient.
6. Send.

Do not share SMTP passwords with unauthorised staff.

### WhatsApp

Supported documents/links may be shared through WhatsApp Web. A working browser and internet connection are required.

---

## 21. Importing Data

Airmonlink supports CSV/XLSX import for supported data.

### Before importing

1. Create a backup.
2. Review the import template/columns.
3. Remove obvious duplicates.
4. Confirm prices and quantities.
5. Use preview/validation.

### Import

1. Open Import.
2. Select the CSV or XLSX file.
3. Review preview and validation messages.
4. Correct errors before committing.
5. Start the import.
6. Review the resulting records.

The import workflow uses transaction handling to reduce partial-data problems if an import fails.

---

## 22. Exporting Data

Use export functions to create supported external copies of business information.

Possible output formats include CSV, PDF, and database-related exports depending on the feature.

Keep exports containing customer or financial information secure.

---

## 23. Backup and Restore

### Create a backup

1. Open Backup/Restore.
2. Choose Create Backup.
3. Select or confirm the backup location.
4. Complete the backup.
5. Verify the backup file exists.
6. Copy important backups to another device or secure remote location.

Supported backup data may be encrypted using AES-GCM.

### Recommended backup practice

- Back up before major imports.
- Back up before software/database maintenance.
- Back up at the end of important business periods.
- Keep more than one backup generation.
- Do not keep your only backup on the same computer as the live database.

### Restore

> **Warning:** Restoring changes the active business data. Confirm the selected backup before proceeding.

1. Create a current backup first.
2. Open Restore.
3. Select the intended backup file.
4. Review confirmation information.
5. Start restore.
6. Do not switch off the computer during the operation.
7. Reopen/check important records after completion.

Restore protection/rollback handling is designed to reduce the risk of losing the existing working database when a restore fails.

### Optional WebDAV backup

If configured, supported backups can be uploaded to WebDAV remote storage. Core business operation does not depend on WebDAV.

---

## 24. Licence Activation

Airmonlink uses server-backed licensing.

### Activate a purchased licence

1. Connect the computer to the internet.
2. Open **Licence**.
3. Enter the business/organisation name.
4. Paste the licence key exactly as issued.
5. Choose **Activate Licence**.
6. Wait for confirmation.
7. Keep the licence purchase information in a safe place.

The licence may be associated with the Windows device. The application periodically validates licence status online.

### If activation fails

Check:

- Internet connection
- Licence key spelling
- Business name
- Correct system date/time
- Whether the licence is already using its allowed device limit

Use official Airmonlink support if the key still cannot be activated.

### Deactivation

Use **Deactivate this device** when you intentionally need to remove that activation according to the licence terms.

---

## 25. Software Updates

Airmonlink can use HTTPS update information and SHA-256 verification for supported update downloads.

Before a major update:

1. Create a backup.
2. Close important work.
3. Download/install only from official Airmonlink sources.
4. Do not delete the business database manually.

Application upgrades are designed so customer data is stored separately from the normal installation folder.

---

## 26. Common Troubleshooting

### Application will not open

1. Restart Windows.
3. Confirm the app is installed correctly.
3. Check whether Windows security blocked the executable.
4. Try launching from the installed shortcut.
5. Contact support with the exact error message if it continues.

### Product cannot be found at POS

- Search by name, SKU, or barcode.
- Confirm the product exists.
- Confirm the barcode/SKU is correct.
- Confirm the correct branch/inventory context.

### Cash sale cannot complete

A cash sale may require an open cash shift.

1. Open/select a cash register.
2. Enter the opening float.
3. Open the shift.
4. Return to POS.

### Stock is wrong

Review:

- Sales
- Returns
- Goods receipts
- Stock adjustments
- Physical counts
- Branch transfers

Do not fix unexplained differences without recording an appropriate adjustment reason.

### Report is empty

- Check date range.
- Check branch/filter.
- Confirm transactions exist for the selected period.
- Review whether the relevant transactions were completed/posted.

### Receipt or report is blank

- Use Print Preview.
- Run Printer Test Page.
- Confirm paper size and selected printer.
- Confirm the printer works from Windows.
- Regenerate the document.

### Email does not send

- Confirm internet connection.
- Verify SMTP host, port, username, password, and security settings.
- Check the recipient address.
- Review provider restrictions.

### Backup will not restore

- Confirm the correct file.
- Confirm the file is not incomplete/corrupted.
- Ensure the app has access to the file.
- Do not overwrite or delete the live database manually.

---

## 27. Daily Operating Checklist

### Opening

- Start Airmonlink.
- Confirm correct branch.
- Confirm printer/scanner if required.
- Open the correct cash register shift.
- Review important low-stock conditions.

### During the day

- Record all sales.
- Record expenses.
- Record customer/supplier payments.
- Receive purchases properly.
- Use returns/refunds workflow for returns.
- Avoid manual stock changes when a proper workflow exists.

### Closing

- Finish pending transactions.
- Close cash shift and review variance.
- Review key sales/stock information.
- Create a backup according to your schedule.

---

## 28. Data and Security Guidance

- Do not share owner credentials.
- Do not share licence credentials publicly.
- Restrict sensitive permissions.
- Keep Windows updated.
- Use trusted antivirus/security software.
- Back up regularly.
- Protect exported customer/financial data.
- Do not modify the SQLite database manually unless instructed by qualified support.
- Do not delete application-support folders to troubleshoot an installation problem.

---

## 29. Internet Requirements

Airmonlink is offline-first. A permanent internet connection is not required for normal local business operations.

Internet access is required for functions such as:

- Licence activation and periodic licence validation
- Software update services
- SMTP email delivery
- Optional WebDAV backup upload
- WhatsApp Web/external links

---

## 30. System Requirements

- Windows 10 or Windows 11
- 64-bit/x64 computer
- Sufficient storage for application data, PDFs, exports, and backups
- Windows-compatible printer if printing is required
- Optional USB keyboard/HID barcode scanner
- Internet connection for licensing and online services

---

## 31. Getting Support

When requesting support, provide:

- Airmonlink version/build
- Windows version
- What you were trying to do
- Exact error message
- Whether the issue happens every time
- Whether a recent update/import/restore occurred

Never send staff PINs, licence secrets, email passwords, database passwords, or other private credentials in public support messages.

---

## 32. Quick Reference

**Make a sale:** Point of Sale → Add products → Select payment → Complete → Print receipt  
**Open cash shift:** Cash Registers/Shifts → Select register → Opening float → Open  
**Add stock manually:** Stock Adjustment → Select product → Increase → Quantity → Reason → Confirm  
**Physical count:** Stock Count → Select product → Enter counted quantity → Confirm  
**Create invoice:** Commercial Documents → Invoice → Customer → Add lines → Save → Print/Email  
**Create purchase order:** Purchase Orders → Supplier → Products → Quantities → Save  
**Receive goods:** Goods Receipt → Purchase order → Actual quantities received → Confirm  
**Return item:** Returns → Original sale → Item → Quantity → Reason → Refund/Restock → Confirm  
**Create backup:** Backup/Restore → Create Backup → Verify file  
**Activate licence:** Licence → Business name → Licence key → Activate

---

## Final Reminder

Airmonlink Business Manager is designed to support real business operations, but the quality of reports and balances depends on accurate data entry. Use the correct workflow for sales, purchases, payments, returns, expenses, stock changes, and cash movements.

**Back up regularly. Review staff permissions. Confirm transactions before posting.**
