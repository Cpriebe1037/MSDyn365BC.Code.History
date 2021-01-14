page 9194 "Designer Diagnostics ListPart"
{
    PageType = ListPart;
    SourceTable = "Designer Diagnostic";
    SourceTableTemporary = true;
    SourceTableView = where(Severity = filter(<> Hidden));
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    Caption = 'Diagnostics';

    layout
    {
        area(Content)
        {
            repeater(repeater)
            {
                field(Severity; Severity)
                {
                    ApplicationArea = All;
                    width = 5;
                    ToolTip = 'Specifies the severity of this diagnostics message.';
                    StyleExpr = SeverityStyleExpr;
                }
                field(Message; Message)
                {
                    Caption = 'Technical details';
                    ApplicationArea = All;
                    ToolTip = 'The details of the problem output by the system.';
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        case Severity of
            Severity::Error:
                SeverityStyleExpr := 'Unfavorable';
            Severity::Warning:
                SeverityStyleExpr := 'Ambiguous';
            Severity::Information:
                SeverityStyleExpr := 'Favorable';
            else
                SeverityStyleExpr := 'Favorable';
        end;
    end;

    procedure SetRecords(var TempDesignerDiagnostics: Record "Designer Diagnostic" temporary)
    begin
        Rec.Copy(TempDesignerDiagnostics, true);
    end;

    var
        SeverityStyleExpr: Text;
}
