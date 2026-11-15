# SBILL hardware compatibility

## Barcode scanners

The Billing search field supports keyboard-wedge scanners. Most USB and Bluetooth HID scanners behave like a keyboard: they type the barcode into the focused search field and send Enter. SBILL then attempts an exact barcode/SKU match and adds the product to the cart.

Recommended setup:
1. Pair/connect the scanner using the operating system.
2. Open Billing and focus the product search field.
3. Configure the scanner suffix as Enter/CR.
4. Scan a known product barcode and confirm that the correct product is added.
5. Test leading-zero barcodes and disconnect/reconnect behaviour.

This path does not require camera permission. Camera-based scanning and vendor-specific serial/Bluetooth protocols are not implemented in this release.

## Printers

SBILL uses the Flutter Printing system print dialog for A4 PDF and 80 mm thermal receipt layouts. A printer must be installed and exposed by Android/Windows/macOS. The print dialog, printer driver and printer hardware determine final margins, paper width, cutter behaviour and density.

For thermal printers:
- Select the 80 mm receipt option in invoice details.
- Set the printer paper width to 80 mm in its driver.
- Disable unexpected driver scaling where possible.
- Print a test receipt with long product names and a multi-line address.
- Confirm that the printer does not clip the final total or footer.

Direct ESC/POS Bluetooth printing, drawer-kick commands, cash-drawer status, and printer-specific code-page selection are not yet implemented. Do not assume that a printer's cash-drawer port will open through the standard PDF print flow.

## Release hardware test matrix

| Hardware | Expected support | Verification |
|---|---|---|
| USB HID barcode scanner | Keyboard input + Enter | Scan exact SKU/barcode |
| Bluetooth HID scanner | Keyboard input + Enter | Pair, scan, reconnect |
| A4 printer | System PDF print | Multi-page A4 test |
| 80 mm thermal printer | System PDF print | Long receipt and clipping test |
| Cash drawer | Not yet supported directly | Requires ESC/POS adapter |
