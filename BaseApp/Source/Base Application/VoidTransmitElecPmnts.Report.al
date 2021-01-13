report 9200 "Void/Transmit Elec. Pmnts"
{
    Caption = 'Void/Transmit Electronic Payments';
    ProcessingOnly = true;

    dataset
    {
        dataitem("Gen. Journal Line"; "Gen. Journal Line")
        {
            DataItemTableView = SORTING("Journal Template Name", "Journal Batch Name", "Line No.") WHERE("Document Type" = FILTER(Payment | Refund), "Bank Payment Type" = FILTER("Electronic Payment" | "Electronic Payment-IAT"), "Exported to Payment File" = CONST(true), "Check Transmitted" = CONST(false));

            trigger OnAfterGetRecord()
            begin
                if SkipReport("Account Type", "Bal. Account Type", "Account No.", "Bal. Account No.", BankAccount."No.") then
                    CurrReport.Skip;

                if FirstTime then begin
                    case UsageType of
                        UsageType::Void:
                            if "Check Transmitted" then
                                Error(AlreadyTransmittedNoVoidErr);
                        UsageType::Transmit:
                            begin
                                if "Check Transmitted" then
                                    Error(AlreadyTransmittedErr);
                                if "Document No." = '' then
                                    Error(VoidedOrNoDocNoErr);
                                if not RTCConfirmTransmit then
                                    exit;
                            end;
                    end;
                    FirstTime := false;
                end;
                CheckManagement.ProcessElectronicPayment("Gen. Journal Line", UsageType);

                if UsageType = UsageType::Void then begin
                    "Check Printed" := false;
                    "Document No." := '';
                end else
                    "Check Transmitted" := true;

                Modify;
            end;

            trigger OnPostDataItem()
            var
                ExpUserFeedbackGenJnl: Codeunit "Exp. User Feedback Gen. Jnl.";
            begin
                if UsageType = UsageType::Void then
                    ExpUserFeedbackGenJnl.SetGivenExportFlagOnGenJnlLine("Gen. Journal Line", false);
            end;

            trigger OnPreDataItem()
            begin
                FirstTime := true;
            end;
        }
    }

    requestpage
    {
        SaveValues = false;

        layout
        {
            area(content)
            {
                group(Options)
                {
                    Caption = 'Options';
                    field("BankAccount.""No."""; BankAccount."No.")
                    {
                        ApplicationArea = Basic, Suite;
                        Caption = 'Bank Account No.';
                        TableRelation = "Bank Account";
                        ToolTip = 'Specifies the bank account that the payment is transmitted to.';
                    }
                    field(DisplayUsageType; DisplayUsageType)
                    {
                        ApplicationArea = Basic, Suite;
                        Caption = 'Operation';
                        Editable = false;
                        OptionCaption = ',Void,Transmit';
                        ToolTip = 'Specifies if you want to transmit or void the electronic payment file. The Transmit option produces an electronic payment file to be transmitted to your bank for processing. The Void option voids the exported file. Confirm that the correct selection has been made before you process the electronic payment file.';
                    }
                }
            }
        }

        actions
        {
        }

        trigger OnOpenPage()
        begin
            DisplayUsageType := UsageType;
            if DisplayUsageType = 0 then
                Error(OnlyRunFromPaymentJournalErr);
        end;
    }

    labels
    {
    }

    trigger OnPreReport()
    begin
        BankAccount.Get(BankAccount."No.");
        BankAccount.TestField(Blocked, false);

        if UsageType <> UsageType::Transmit then
            if not Confirm(ActionConfirmQst,
                 false,
                 UsageType,
                 BankAccount.TableCaption,
                 BankAccount."No.")
            then
                CurrReport.Quit;
    end;

    var
        BankAccount: Record "Bank Account";
        CheckManagement: Codeunit CheckManagement;
        FirstTime: Boolean;
        UsageType: Option ,Void,Transmit;
        DisplayUsageType: Option ,Void,Transmit;
        ActionConfirmQst: Label 'Are you SURE you want to %1 all of the Electronic Payments written against %2 %3?', Comment = '%1=Action taken., %2=Name of the Bank Account table., %3=Bank Account Number.';
        AlreadyTransmittedNoVoidErr: Label 'The export file has already been transmitted. You can no longer void these entries.';
        AlreadyTransmittedErr: Label 'The export file has already been transmitted.';
        OnlyRunFromPaymentJournalErr: Label 'This process can only be run from the Payment Journal.';
        TransmittedQst: Label 'Has export file been successfully transmitted?';
        VoidedOrNoDocNoErr: Label 'The export file cannot be transmitted if the payment has been voided or is missing a Document No.';

    procedure SetUsageType(NewUsageType: Option ,Void,Transmit)
    begin
        UsageType := NewUsageType;
    end;

    procedure RTCConfirmTransmit(): Boolean
    begin
        if not Confirm(TransmittedQst, false) then
            exit(false);

        exit(true);
    end;

    procedure SetBankAccountNo(AccountNumber: Code[20])
    begin
        BankAccount.Get(AccountNumber);
    end;

    local procedure SkipReport(AccountType: Option "G/L Account",Customer,Vendor,"Bank Account","Fixed Asset","IC Partner"; BalAccountType: Option "G/L Account",Customer,Vendor,"Bank Account","Fixed Asset","IC Partner"; AccountNo: Code[20]; BalAccountNo: Code[20]; BankAccountNo: Code[20]): Boolean
    begin
        if AccountType = AccountType::"Bank Account" then
            if AccountNo <> BankAccountNo then
                exit(true);

        if BalAccountType = BalAccountType::"Bank Account" then
            if BalAccountNo <> BankAccountNo then
                exit(true);

        if (AccountType <> AccountType::"Bank Account") and (BalAccountType <> BalAccountType::"Bank Account") then
            exit(true);
    end;
}

