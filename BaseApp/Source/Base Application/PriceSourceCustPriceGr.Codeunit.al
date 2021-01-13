codeunit 7033 "Price Source - Cust. Price Gr." implements "Price Source"
{
    var
        CustomerPriceGroup: Record "Customer Price Group";
        ParentErr: Label 'Parent Source No. must be blank for Customer Price Group source type.';

    procedure GetNo(var PriceSource: Record "Price Source")
    begin
        with PriceSource do
            if CustomerPriceGroup.GetBySystemId("Source ID") then
                "Source No." := CustomerPriceGroup.Code
            else
                InitSource();
    end;

    procedure GetId(var PriceSource: Record "Price Source")
    begin
        with PriceSource do
            if CustomerPriceGroup.Get("Source No.") then
                "Source ID" := CustomerPriceGroup.SystemId
            else
                InitSource();
    end;

    procedure IsForAmountType(AmountType: Enum "Price Amount Type"): Boolean
    begin
        exit(AmountType = AmountType::Price);
    end;

    procedure IsSourceNoAllowed() Result: Boolean;
    begin
        Result := true;
    end;

    procedure IsLookupOK(var PriceSource: Record "Price Source"): Boolean
    begin
        with PriceSource do begin
            if CustomerPriceGroup.Get("Source No.") then;
            if Page.RunModal(Page::"Customer Price Groups", CustomerPriceGroup) = ACTION::LookupOK then begin
                Validate("Source No.", CustomerPriceGroup.Code);
                exit(true);
            end;
        end;
    end;

    procedure VerifyParent(var PriceSource: Record "Price Source") Result: Boolean
    begin
        if PriceSource."Parent Source No." <> '' then
            Error(ParentErr);
    end;

    procedure GetGroupNo(PriceSource: Record "Price Source"): Code[20];
    begin
    end;
}