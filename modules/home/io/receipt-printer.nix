# Client-side helpers for printing to milo's network receipt printer
# Usage: Import this module in your home-manager config to get network printing commands
{ config, pkgs, lib, ... }:

{
  home.packages = [
    # Print a pre-generated .prn file to the network printer
    (pkgs.writeShellScriptBin "print-receipt-network" ''
      #!/usr/bin/env bash
      # Print receipt file to milo's network printer
      # Usage: print-receipt-network receipt.prn

      PRINTER_HOST="milo.local"
      PRINTER_PORT="631"
      PRINTER_NAME="EPSON_TM-T88V"

      if [ $# -eq 0 ]; then
        echo "Usage: print-receipt-network <file.prn>"
        echo "Example: print-receipt-network receipt.prn"
        exit 1
      fi

      FILE="$1"

      if [ ! -f "$FILE" ]; then
        echo "Error: File not found: $FILE"
        exit 1
      fi

      echo "Sending $FILE to $PRINTER_HOST:$PRINTER_PORT/$PRINTER_NAME..."
      ${pkgs.cups}/bin/lp -h "$PRINTER_HOST:$PRINTER_PORT" -d "$PRINTER_NAME" -o raw "$FILE"

      if [ $? -eq 0 ]; then
        echo "Print job sent successfully!"
      else
        echo "Error: Print job failed"
        echo "Make sure milo is online and the printer is configured"
        exit 1
      fi
    '')

    # Generate and print Mietzahlungsquittung directly to network printer
    (pkgs.writeShellScriptBin "mietzahlungsquittung-network" ''
      #!/usr/bin/env bash
      # Wrapper for mietzahlungsquittung.py that prints to network printer
      # Usage: mietzahlungsquittung-network --date 2025-01-15 --amount 850.00 --name "Your Name" --number 001

      PRINTER_HOST="milo.local"
      PRINTER_PORT="631"
      PRINTER_NAME="EPSON_TM-T88V"
      SCRIPT="$HOME/org/admin/Skali/remise/money/mietzahlungsquittung.py"

      if [ ! -f "$SCRIPT" ]; then
        echo "Error: Script not found at $SCRIPT"
        exit 1
      fi

      # Generate receipt to temp file
      TMPFILE=$(mktemp --suffix=.prn)
      trap "rm -f $TMPFILE" EXIT

      # Generate receipt
      ${pkgs.python3}/bin/python3 "$SCRIPT" "$@" --save "$TMPFILE"

      if [ $? -ne 0 ]; then
        echo "Error: Failed to generate receipt"
        exit 1
      fi

      # Send to network printer
      echo "Sending to $PRINTER_HOST:$PRINTER_PORT/$PRINTER_NAME..."
      ${pkgs.cups}/bin/lp -h "$PRINTER_HOST:$PRINTER_PORT" -d "$PRINTER_NAME" -o raw "$TMPFILE"

      if [ $? -eq 0 ]; then
        echo "Receipt printed successfully!"
      else
        echo "Error: Print job failed"
        echo "Make sure milo is online and the printer is configured"
        exit 1
      fi
    '')
  ];
}
