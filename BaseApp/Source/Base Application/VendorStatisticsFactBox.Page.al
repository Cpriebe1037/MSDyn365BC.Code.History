page 9094 "Vendor Statistics FactBox"
{
    Caption = 'Vendor Statistics';
    PageType = CardPart;
    SourceTable = Vendor;

    layout
    {
        area(content)
        {
            field("No."; "No.")
            {
                ApplicationArea = All;
                Caption = 'Vendor No.';
                ToolTip = 'Specifies the number of the vendor. The field is either filled automatically from a defined number series, or you enter the number manually because you have enabled manual number entry in the number-series setup.';

                trigger OnDrillDown()
                begin
                    ShowDetails;
                end;
            }
            field("Balance (LCY)"; "Balance (LCY)")
            {
                ApplicationArea = Basic, Suite;
                ToolTip = 'Specifies the total value of your completed purchases from the vendor in the current fiscal year. It is calculated from amounts excluding VAT on all completed purchase invoices and credit memos.';

                trigger OnDrillDown()
                var
                    VendLedgEntry: Record "Vendor Ledger Entry";
                    DtldVendLedgEntry: Record "Detailed Vendor Ledg. Entry";
                begin
                    DtldVendLedgEntry.SetRange("Vendor No.", "No.");
                    CopyFilter("Global Dimension 1 Filter", DtldVendLedgEntry."Initial Entry Global Dim. 1");
                    CopyFilter("Global Dimension 2 Filter", DtldVendLedgEntry."Initial Entry Global Dim. 2");
                    CopyFilter("Currency Filter", DtldVendLedgEntry."Currency Code");
                    VendLedgEntry.DrillDownOnEntries(DtldVendLedgEntry);
                end;
            }
            field("Outstanding Orders (LCY)"; "Outstanding Orders (LCY)")
            {
                ApplicationArea = Basic, Suite;
                ToolTip = 'Specifies the sum of outstanding orders (in LCY) to this vendor.';
            }
            field("Amt. Rcd. Not Invoiced (LCY)"; "Amt. Rcd. Not Invoiced (LCY)")
            {
                ApplicationArea = Basic, Suite;
                Caption = 'Amt. Rcd. Not Invd. (LCY)';
                ToolTip = 'Specifies the total invoice amount (in LCY) for the items you have received but not yet been invoiced for.';
            }
            field("Outstanding Invoices (LCY)"; "Outstanding Invoices (LCY)")
            {
                ApplicationArea = Basic, Suite;
                ToolTip = 'Specifies the sum of the vendor''s outstanding purchase invoices in LCY.';
            }
            field(TotalAmountLCY; TotalAmountLCY)
            {
                ApplicationArea = Basic, Suite;
                AutoFormatType = 1;
                Caption = 'Total (LCY)';
                ToolTip = 'Specifies the payment amount that you owe the vendor for completed purchases plus purchases that are still ongoing.';
            }
            field("Balance Due (LCY)"; OverDueBalance)
            {
                ApplicationArea = Basic, Suite;
                CaptionClass = Format(StrSubstNo(Text000, Format(WorkDate)));
                Caption = 'Balance Due (LCY)';

                trigger OnDrillDown()
                var
                    VendLedgEntry: Record "Vendor Ledger Entry";
                    DtldVendLedgEntry: Record "Detailed Vendor Ledg. Entry";
                begin
                    DtldVendLedgEntry.SetFilter("Vendor No.", "No.");
                    CopyFilter("Global Dimension 1 Filter", DtldVendLedgEntry."Initial Entry Global Dim. 1");
                    CopyFilter("Global Dimension 2 Filter", DtldVendLedgEntry."Initial Entry Global Dim. 2");
                    CopyFilter("Currency Filter", DtldVendLedgEntry."Currency Code");
                    VendLedgEntry.DrillDownOnOverdueEntries(DtldVendLedgEntry);
                end;
            }
            field(GetInvoicedPrepmtAmountLCY; InvoicedPrepmtAmountLCY)
            {
                ApplicationArea = Prepayments;
                Caption = 'Invoiced Prepayment Amount (LCY)';
                ToolTip = 'Specifies your payments to the vendor, based on invoiced prepayments.';
            }
            field("Payments (LCY)"; "Payments (LCY)")
            {
                ApplicationArea = Basic, Suite;
                ToolTip = 'Specifies the sum of payments paid to the vendor.';
            }
            field("Refunds (LCY)"; "Refunds (LCY)")
            {
                ApplicationArea = Basic, Suite;
                ToolTip = 'Specifies the sum of refunds paid to the vendor.';
            }
            field(LastPaymentDate; LastPaymentDate)
            {
                AccessByPermission = TableData "Vendor Ledger Entry" = R;
                ApplicationArea = Basic, Suite;
                Caption = 'Last Payment Date';
                ToolTip = 'Specifies the posting date of the last payment paid to the vendor.';

                trigger OnDrillDown()
                var
                    VendorLedgerEntry: Record "Vendor Ledger Entry";
                    VendorLedgerEntries: Page "Vendor Ledger Entries";
                begin
                    Clear(VendorLedgerEntries);
                    SetFilterLastPaymentDateEntry(VendorLedgerEntry);
                    if VendorLedgerEntry.FindLast then
                        VendorLedgerEntries.SetRecord(VendorLedgerEntry);
                    VendorLedgerEntries.SetTableView(VendorLedgerEntry);
                    VendorLedgerEntries.Run;
                end;
            }
        }
    }

    actions
    {
    }

    trigger OnAfterGetRecord()
    var
        VendorNo: Code[20];
        VendorNoFilter: Text;
    begin
        FilterGroup(4);
        SetAutoCalcFields("Balance (LCY)", "Outstanding Orders (LCY)", "Amt. Rcd. Not Invoiced (LCY)", "Outstanding Invoices (LCY)");
        TotalAmountLCY := "Balance (LCY)" + "Outstanding Orders (LCY)" + "Amt. Rcd. Not Invoiced (LCY)" + "Outstanding Invoices (LCY)";

        // Get the vendor number and set the current vendor number
        VendorNoFilter := GetFilter("No.");
        if (VendorNoFilter = '') then begin
            FilterGroup(0);
            VendorNoFilter := GetFilter("No.");
        end;

        VendorNo := CopyStr(VendorNoFilter, 1, MaxStrLen(VendorNo));
        if VendorNo <> CurrVendorNo then begin
            CurrVendorNo := VendorNo;
            CalculateFieldValues(CurrVendorNo);
        end;
    end;

    trigger OnFindRecord(Which: Text): Boolean
    begin
        TotalAmountLCY := 0;

        exit(Find(Which));
    end;

    var
        Text000: Label 'Overdue Amounts (LCY) as of %1';
        ShowVendorNo: Boolean;
        TaskIdCalculateCue: Integer;
        CurrVendorNo: Code[20];

    protected var
        TotalAmountLCY: Decimal;
        LastPaymentDate: Date;
        InvoicedPrepmtAmountLCY: Decimal;
        OverdueBalance: Decimal;

    procedure CalculateFieldValues(VendorNo: Code[20])
    var
        CalculateVendorStats: Codeunit "Calculate Vendor Stats.";
        Args: Dictionary of [Text, Text];
    begin
        if (TaskIdCalculateCue <> 0) then
            CurrPage.CancelBackgroundTask(TaskIdCalculateCue);

        Clear(LastPaymentDate);
        Clear(OverdueBalance);
        Clear(InvoicedPrepmtAmountLCY);

        if VendorNo = '' then
            exit;

        Args.Add(CalculateVendorStats.GetVendorNoLabel(), VendorNo);
        CurrPage.EnqueueBackgroundTask(TaskIdCalculateCue, Codeunit::"Calculate Vendor Stats.", Args);
    end;

    trigger OnPageBackgroundTaskCompleted(TaskId: Integer; Results: Dictionary of [Text, Text])
    var
        CalculateVendorStats: Codeunit "Calculate Vendor Stats.";
        DictionaryValue: Text;
    begin
        if (TaskId = TaskIdCalculateCue) then begin
            if Results.Count() = 0 then
                exit;

            if TryGetDictionaryValueFromKey(Results, CalculateVendorStats.GetLastPaymentDateLabel(), DictionaryValue) then
                Evaluate(LastPaymentDate, DictionaryValue);

            if TryGetDictionaryValueFromKey(Results, CalculateVendorStats.GetOverdueBalanceLabel(), DictionaryValue) then
                Evaluate(OverdueBalance, DictionaryValue);

            if TryGetDictionaryValueFromKey(Results, CalculateVendorStats.GetInvoicedPrepmtAmountLCYLabel(), DictionaryValue) then
                Evaluate(InvoicedPrepmtAmountLCY, DictionaryValue);
        end;
    end;

    [TryFunction]
    local procedure TryGetDictionaryValueFromKey(var DictionaryToLookIn: Dictionary of [Text, Text]; KeyToSearchFor: Text; var ReturnValue: Text)
    begin
        ReturnValue := DictionaryToLookIn.Get(KeyToSearchFor);
    end;

    local procedure ShowDetails()
    begin
        PAGE.Run(PAGE::"Vendor Card", Rec);
    end;

    [Obsolete('Visibility of the Vendor No. can be controlled through personalizaition or PTE', '17.0')]
    procedure SetVendorNoVisibility(Visible: Boolean)
    begin
        ShowVendorNo := Visible;
    end;

    local procedure SetFilterLastPaymentDateEntry(var VendorLedgerEntry: Record "Vendor Ledger Entry")
    begin
        VendorLedgerEntry.SetCurrentKey("Document Type", "Vendor No.", "Posting Date", "Currency Code");
        VendorLedgerEntry.SetRange("Vendor No.", "No.");
        VendorLedgerEntry.SetRange("Document Type", VendorLedgerEntry."Document Type"::Payment);
        VendorLedgerEntry.SetRange(Reversed, false);
    end;

}

