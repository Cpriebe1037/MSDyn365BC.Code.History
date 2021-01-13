page 11306 "Representative Card"
{
    Caption = 'Representative Card';
    PageType = Card;
    SourceTable = Representative;

    layout
    {
        area(content)
        {
            group(General)
            {
                Caption = 'General';
                field(ID; ID)
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies the identifier for the representative.';
                }
                field(Name; Name)
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies the name of the VAT declaration representative.';
                }
                field(Address; Address)
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies the address that is associated with the VAT declaration representative.';
                }
                field("Post Code"; "Post Code")
                {
                    ApplicationArea = Basic, Suite;
                    Caption = 'Post Code/City';
                    ToolTip = 'Specifies the postal code that is associated with the VAT declaration representative.';
                }
                field(City; City)
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies the city that is associated with the VAT declaration representative.';
                }
                field("Country/Region Code"; "Country/Region Code")
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies the country or region code that is associated with the VAT declaration representative.';
                }
                field(County; County)
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies the county that is associated with the VAT declaration representative.';
                }
                field("E-Mail"; "E-Mail")
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies the email address of the VAT declaration representative.';
                }
                field(Phone; Phone)
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies the phone number of the VAT declaration representative.';
                }
                field("Issued by"; "Issued by")
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies the country/region that issued the VAT declaration representative.';
                }
                field("Identification Type"; "Identification Type")
                {
                    ApplicationArea = Basic, Suite;
                    ToolTip = 'Specifies the identification type that is associated with the VAT declaration representative. Identification types include NVAT and TIN.';
                }
            }
        }
    }

    actions
    {
    }
}
