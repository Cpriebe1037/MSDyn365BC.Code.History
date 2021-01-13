table 11780 "VAT Period"
{
    Caption = 'VAT Period';
    LookupPageID = "VAT Periods";

    fields
    {
        field(1; "Starting Date"; Date)
        {
            Caption = 'Starting Date';
            NotBlank = true;

            trigger OnValidate()
            begin
                Name := Format("Starting Date", 0, MonthTxt);
            end;
        }
        field(2; Name; Text[10])
        {
            Caption = 'Name';
        }
        field(3; "New VAT Year"; Boolean)
        {
            Caption = 'New VAT Year';
        }
        field(4; Closed; Boolean)
        {
            Caption = 'Closed';
        }
    }

    keys
    {
        key(Key1; "Starting Date")
        {
            Clustered = true;
        }
        key(Key2; "New VAT Year")
        {
        }
        key(Key3; Closed)
        {
        }
    }

    fieldgroups
    {
    }

    var
        VATPeriod2: Record "VAT Period";
        MonthTxt: Label '<Month Text>', Locked = true;
}

