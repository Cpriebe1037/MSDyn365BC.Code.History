table 31103 "VAT Control Report Buffer"
{
    Caption = 'VAT Control Report Buffer';

    fields
    {
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
            DataClassification = SystemMetadata;
        }
        field(5; "VAT Control Rep. Section Code"; Code[20])
        {
            Caption = 'VAT Control Rep. Section Code';
            DataClassification = SystemMetadata;
            TableRelation = "VAT Control Report Section";
        }
        field(11; "Posting Date"; Date)
        {
            Caption = 'Posting Date';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(12; "VAT Date"; Date)
        {
            Caption = 'VAT Date';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(13; "Original Document VAT Date"; Date)
        {
            Caption = 'Original Document VAT Date';
            DataClassification = SystemMetadata;
        }
        field(15; "Bill-to/Pay-to No."; Code[20])
        {
            Caption = 'Bill-to/Pay-to No.';
            DataClassification = SystemMetadata;
            TableRelation = IF (Type = CONST(Purchase)) Vendor
            ELSE
            IF (Type = CONST(Sale)) Customer;
        }
        field(16; "VAT Registration No."; Text[20])
        {
            Caption = 'VAT Registration No.';
            DataClassification = SystemMetadata;
        }
        field(17; "Registration No."; Text[20])
        {
            Caption = 'Registration No.';
            DataClassification = SystemMetadata;
        }
        field(18; "Tax Registration No."; Text[20])
        {
            Caption = 'Tax Registration No.';
            DataClassification = SystemMetadata;
        }
        field(20; "Document No."; Code[35])
        {
            Caption = 'Document No.';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(21; "External Document No."; Code[35])
        {
            Caption = 'External Document No.';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(30; Type; Option)
        {
            Caption = 'Type';
            DataClassification = SystemMetadata;
            Editable = false;
            OptionCaption = ' ,Purchase,Sale';
            OptionMembers = " ",Purchase,Sale;
        }
        field(31; "VAT Bus. Posting Group"; Code[20])
        {
            Caption = 'VAT Bus. Posting Group';
            DataClassification = SystemMetadata;
            Editable = false;
            TableRelation = "VAT Business Posting Group";
        }
        field(32; "VAT Prod. Posting Group"; Code[20])
        {
            Caption = 'VAT Prod. Posting Group';
            DataClassification = SystemMetadata;
            Editable = false;
            TableRelation = "VAT Product Posting Group";
        }
        field(35; "VAT Calculation Type"; Enum "Tax Calculation Type")
        {
            Caption = 'VAT Calculation Type';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(40; "VAT Rate"; Option)
        {
            Caption = 'VAT Rate';
            DataClassification = SystemMetadata;
            OptionCaption = ',Base,Reduced,Reduced 2';
            OptionMembers = ,Base,Reduced,"Reduced 2";
        }
        field(41; "Commodity Code"; Code[10])
        {
            Caption = 'Commodity Code';
            DataClassification = SystemMetadata;
            TableRelation = Commodity;
        }
        field(42; "Supplies Mode Code"; Option)
        {
            Caption = 'Supplies Mode Code';
            DataClassification = SystemMetadata;
            OptionCaption = '0,1,2';
            OptionMembers = "0","1","2";
        }
        field(43; "Corrections for Bad Receivable"; Option)
        {
            Caption = 'Corrections for Bad Receivable';
            OptionCaption = ' ,Insolvency Proceedings (p.44),Bad Receivable (p.46 resp. 74a)';
            OptionMembers = " ","Insolvency Proceedings (p.44)","Bad Receivable (p.46 resp. 74a)";
            DataClassification = SystemMetadata;
        }
        field(44; "Insolvency Proceedings (p.44)"; Boolean)
        {
            Caption = 'Insolvency Proceedings (p.44)';
            ObsoleteState = Removed;
            ObsoleteReason = 'Replaced by "Corrections for Bad Receivable"';
            DataClassification = SystemMetadata;
            ObsoleteTag = '15.0';
        }
        field(45; "Ratio Use"; Boolean)
        {
            Caption = 'Ratio Use';
            DataClassification = SystemMetadata;
        }
        field(46; Name; Text[50])
        {
            Caption = 'Name';
            DataClassification = SystemMetadata;
        }
        field(47; "Birth Date"; Date)
        {
            Caption = 'Birth Date';
            DataClassification = SystemMetadata;
        }
        field(48; "Place of stay"; Text[50])
        {
            Caption = 'Place of stay';
            DataClassification = SystemMetadata;
        }
        field(60; "Base 1"; Decimal)
        {
            AutoFormatType = 2;
            Caption = 'Base (base)';
            DataClassification = SystemMetadata;
        }
        field(61; "Amount 1"; Decimal)
        {
            AutoFormatType = 2;
            Caption = 'Amount (base)';
            DataClassification = SystemMetadata;
        }
        field(62; "Base 2"; Decimal)
        {
            AutoFormatType = 2;
            Caption = 'Base (reduced)';
            DataClassification = SystemMetadata;
        }
        field(63; "Amount 2"; Decimal)
        {
            AutoFormatType = 2;
            Caption = 'Amount (reduced)';
            DataClassification = SystemMetadata;
        }
        field(64; "Base 3"; Decimal)
        {
            AutoFormatType = 2;
            Caption = 'Base (2.reduced)';
            DataClassification = SystemMetadata;
        }
        field(65; "Amount 3"; Decimal)
        {
            AutoFormatType = 2;
            Caption = 'Amount (2.reduced)';
            DataClassification = SystemMetadata;
        }
        field(70; "Total Base"; Decimal)
        {
            AutoFormatType = 2;
            Caption = 'Total Base';
            DataClassification = SystemMetadata;
        }
        field(71; "Total Amount"; Decimal)
        {
            AutoFormatType = 2;
            Caption = 'Total Amount';
            DataClassification = SystemMetadata;
        }
        field(100; "VAT Control Rep. Section Desc."; Text[50])
        {
            CalcFormula = Lookup ("VAT Control Report Section".Description WHERE(Code = FIELD("VAT Control Rep. Section Code")));
            Caption = 'VAT Control Rep. Section Desc.';
            Editable = false;
            FieldClass = FlowField;
        }
    }

    keys
    {
        key(Key1; "VAT Control Rep. Section Code", "Line No.")
        {
            Clustered = true;
        }
        key(Key2; "Document No.", "Bill-to/Pay-to No.", "Posting Date")
        {
        }
        key(Key3; "Document No.", "Bill-to/Pay-to No.", "VAT Date")
        {
        }
    }

    fieldgroups
    {
    }
}

