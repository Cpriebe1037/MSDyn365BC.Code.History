page 11303 "Manual VAT Correction List"
{
    Caption = 'Manual VAT Correction List';
    DelayedInsert = true;
    PageType = List;
    SourceTable = "Manual VAT Correction";

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Row No."; "Row No.")
                {
                    ApplicationArea = Basic, Suite;
                    Editable = false;
                    ToolTip = 'Specifies the number of the VAT row to which the VAT correction applies.';
                }
                field("Posting Date"; "Posting Date")
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies the posting date of the VAT correction.';
                }
                field(Amount; Amount)
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies the amount of the VAT correction. For example, if the corrected total of the VAT amount is 1000 instead of 1200, enter 200.';
                }
                field("Additional-Currency Amount"; "Additional-Currency Amount")
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies the amount of the VAT correction in the additional reporting currency.';
                }
            }
        }
    }

    actions
    {
    }

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        if CorrStatementLineNo <> 0 then
            "Statement Line No." := CorrStatementLineNo;
    end;

    var
        CorrStatementLineNo: Integer;

    [Scope('OnPrem')]
    procedure SetCorrStatementLineNo(LineNo: Integer)
    begin
        CorrStatementLineNo := LineNo;
    end;
}
