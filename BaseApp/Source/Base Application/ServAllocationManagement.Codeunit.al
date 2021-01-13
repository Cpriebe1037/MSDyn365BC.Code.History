codeunit 5930 ServAllocationManagement
{
    Permissions = TableData "Service Order Allocation" = rimd;

    trigger OnRun()
    begin
    end;

    var
        Text000: Label 'You cannot allocate a resource to the service order %1 because it is %2.';
        Text001: Label '%1 with the field %2 selected cannot be found.';
        Text002: Label 'Do you want to allocate the %1 %2 to all nonactive Service Order Allocations on the Service Item Lines with the %3 other than %4?';
        Text003: Label 'There are no %1 lines to split the corresponding %2.';
        Text004: Label 'You cannot change the resource allocation for service item line %1 because the %2 is %3.';

    procedure AllocateDate(DocumentType: Integer; DocumentNo: Code[20]; EntryNo: Integer; ResNo: Code[20]; ResGrNo: Code[20]; CurrentDate: Date; Quantity: Decimal)
    var
        ServHeader: Record "Service Header";
        ServOrderAlloc: Record "Service Order Allocation";
    begin
        ServHeader.Get(DocumentType, DocumentNo);
        if ServHeader.Status = ServHeader.Status::Finished then
            Error(
              Text000,
              ServHeader."No.", ServHeader.Status);
        if ServOrderAlloc.Get(EntryNo) then begin
            CheckServiceItemLineFinished(ServHeader, ServOrderAlloc."Service Item Line No.");
            ServOrderAlloc."Allocation Date" := CurrentDate;
            ServOrderAlloc.Validate("Resource No.", ResNo);
            if ResGrNo <> '' then
                ServOrderAlloc.Validate("Resource Group No.", ResGrNo);
            ServOrderAlloc.Validate("Allocated Hours", Quantity);
            ServOrderAlloc.Modify(true);
        end;
    end;

    procedure CancelAllocation(var ServOrderAlloc: Record "Service Order Allocation")
    var
        ServHeader: Record "Service Header";
        ServItemLine: Record "Service Item Line";
        RepairStatus: Record "Repair Status";
        RepairStatus2: Record "Repair Status";
        AddReasonCodeCancelation: Page "Cancelled Allocation Reasons";
        ReasonCode: Code[10];
        RepairStatusCode: Code[10];
        IsHandled: Boolean;
    begin
        IsHandled := false;
        OnBeforeCancelAllocation(ServOrderAlloc, IsHandled);
        if IsHandled then
            exit;

        if ServOrderAlloc."Entry No." = 0 then
            exit;
        ServHeader.Get(ServOrderAlloc."Document Type", ServOrderAlloc."Document No.");
        CheckServiceItemLineFinished(ServHeader, ServOrderAlloc."Service Item Line No.");
        Clear(AddReasonCodeCancelation);
        AddReasonCodeCancelation.SetRecord(ServOrderAlloc);
        AddReasonCodeCancelation.SetTableView(ServOrderAlloc);
        if AddReasonCodeCancelation.RunModal = ACTION::Yes then begin
            ReasonCode := AddReasonCodeCancelation.ReturnReasonCode;
            ServOrderAlloc.Validate(Status, ServOrderAlloc.Status::"Reallocation Needed");
            ServOrderAlloc."Reason Code" := ReasonCode;
            ServOrderAlloc.Modify(true);
            if ServItemLine.Get(
                 ServOrderAlloc."Document Type", ServOrderAlloc."Document No.", ServOrderAlloc."Service Item Line No.")
            then begin
                ServItemLine.Validate(Priority, AddReasonCodeCancelation.ReturnPriority);
                RepairStatusCode := ServItemLine."Repair Status Code";
                RepairStatus.Get(RepairStatusCode);
                if RepairStatus.Initial then begin
                    Clear(RepairStatus2);
                    RepairStatus2.SetRange(Referred, true);
                    if RepairStatus2.FindFirst then
                        RepairStatusCode := RepairStatus2.Code
                    else
                        Error(
                          Text001,
                          RepairStatus.TableCaption, RepairStatus.FieldCaption(Referred));
                end else
                    if RepairStatus."In Process" then begin
                        Clear(RepairStatus2);
                        RepairStatus2.SetRange("Partly Serviced", true);
                        if RepairStatus2.FindFirst then
                            RepairStatusCode := RepairStatus2.Code
                        else
                            Error(
                              Text001,
                              RepairStatus.TableCaption, RepairStatus.FieldCaption("Partly Serviced"));
                    end;
                ServItemLine."Repair Status Code" := RepairStatusCode;
                ServItemLine.Modify(true);
            end else begin
                ServHeader.Get(ServOrderAlloc."Document Type", ServOrderAlloc."Document No.");
                ServHeader.Validate(Priority, AddReasonCodeCancelation.ReturnPriority);
                ServHeader.Modify(true);
            end;
        end;
    end;

    procedure CreateAllocationEntry(DocumentType: Integer; DocumentNo: Code[20]; ServItemLineNo: Integer; ServItemNo: Code[20]; ServSerialNo: Code[50])
    var
        ServHeader: Record "Service Header";
        ServOrderAlloc: Record "Service Order Allocation";
        NewServOrderAlloc: Record "Service Order Allocation";
        IsHandled: Boolean;
    begin
        IsHandled := false;
        OnBeforeCreateAllocationEntry(DocumentType, DocumentNo, ServItemLineNo, ServItemNo, ServSerialNo, IsHandled);
        if IsHandled then
            exit;

        ServHeader.Get(DocumentType, DocumentNo);
        if ServHeader.Status <> ServHeader.Status::Finished then begin
            CheckServiceItemLineFinished(ServHeader, ServOrderAlloc."Service Item Line No.");
            ServOrderAlloc.Reset();
            ServOrderAlloc.SetCurrentKey(Status, "Document Type", "Document No.", "Service Item Line No.");
            ServOrderAlloc.SetFilter(Status, '<>%1', ServOrderAlloc.Status::Canceled);
            ServOrderAlloc.SetRange("Document Type", DocumentType);
            ServOrderAlloc.SetRange("Document No.", DocumentNo);
            ServOrderAlloc.SetRange("Service Item Line No.", ServItemLineNo);
            if not ServOrderAlloc.FindFirst then begin
                NewServOrderAlloc.Init();
                NewServOrderAlloc."Document Type" := DocumentType;
                NewServOrderAlloc."Document No." := DocumentNo;
                NewServOrderAlloc."Service Item Line No." := ServItemLineNo;
                NewServOrderAlloc."Service Item No." := ServItemNo;
                NewServOrderAlloc."Service Item Serial No." := ServSerialNo;
                NewServOrderAlloc.Insert(true);
            end;
        end;
    end;

    procedure SplitAllocation(var SplitServOrderAlloc: Record "Service Order Allocation")
    var
        ServOrderAlloc: Record "Service Order Allocation";
        ServOrderAllocTemp: Record "Service Order Allocation" temporary;
        ServItemLine: Record "Service Item Line";
        Res: Record Resource;
        RepairStatus: Record "Repair Status";
        ConfirmManagement: Codeunit "Confirm Management";
        NoOfRecords: Integer;
        SplitAllocHours: Decimal;
    begin
        with SplitServOrderAlloc do begin
            TestField(Status, Status::Active);
            if not ConfirmManagement.GetResponseOrDefault(
                 StrSubstNo(
                   Text002, Res.TableCaption, "Resource No.", RepairStatus.TableCaption,
                   RepairStatus.FieldCaption(Finished)), true)
            then
                exit;

            ServOrderAlloc.Reset();
            ServOrderAlloc.SetCurrentKey("Document Type", "Document No.", Status);
            ServOrderAlloc.SetRange("Document Type", "Document Type");
            ServOrderAlloc.SetRange("Document No.", "Document No.");
            ServOrderAlloc.SetFilter(Status, '%1|%2',
              ServOrderAlloc.Status::Nonactive, ServOrderAlloc.Status::"Reallocation Needed");
            ServOrderAlloc.SetHideDialog(true);
            if not ServOrderAlloc.Find('-') then
                Error(Text003,
                  ServOrderAlloc.TableCaption, FieldCaption("Allocated Hours"));
            ServOrderAllocTemp.DeleteAll();
            repeat
                ServItemLine.Get(
                  ServOrderAlloc."Document Type",
                  ServOrderAlloc."Document No.",
                  ServOrderAlloc."Service Item Line No.");
                if RepairStatus.Get(ServItemLine."Repair Status Code") then
                    if not RepairStatus.Finished then begin
                        ServOrderAllocTemp := ServOrderAlloc;
                        ServOrderAllocTemp.Insert();
                    end;
            until ServOrderAlloc.Next = 0;

            NoOfRecords := ServOrderAllocTemp.Count + 1;
            if NoOfRecords <> 1 then begin
                SplitAllocHours := Round("Allocated Hours" / NoOfRecords, 0.1);
                ServOrderAllocTemp.Find('-');
                repeat
                    ServOrderAlloc.Get(ServOrderAllocTemp."Entry No.");
                    if ServOrderAlloc."Entry No." <> "Entry No." then begin
                        ServOrderAlloc.Validate("Allocation Date", "Allocation Date");
                        ServOrderAlloc.Validate("Resource No.", "Resource No.");
                        ServOrderAlloc.Validate("Resource Group No.", "Resource Group No.");
                        ServOrderAlloc.Validate("Allocated Hours", SplitAllocHours);
                        ServOrderAlloc.Modify(true);
                    end;
                    Validate("Allocated Hours", SplitAllocHours);
                    Modify(true);
                until ServOrderAllocTemp.Next = 0;
            end else
                Error(Text003,
                  ServOrderAlloc.TableCaption, FieldCaption("Allocated Hours"));
        end;
    end;

    procedure ResourceQualified(ResourceNo: Code[20]; Type: Option Resource,"Service Item Group",Item,"Service Item"; No: Code[20]): Boolean
    var
        ServMgtSetup: Record "Service Mgt. Setup";
        ResourceSkill: Record "Resource Skill";
        ResourceSkill2: Record "Resource Skill";
    begin
        ServMgtSetup.Get();
        if ServMgtSetup."Resource Skills Option" = ServMgtSetup."Resource Skills Option"::"Not Used" then
            exit(false);

        if ResourceNo = '' then
            exit(false);

        ResourceSkill.SetRange(Type, Type);
        ResourceSkill.SetRange("No.", No);
        if ResourceSkill.Find('-') then
            repeat
                if not
                   ResourceSkill2.Get(
                     Type::Resource,
                     ResourceNo,
                     ResourceSkill."Skill Code")
                then
                    exit(false);
            until ResourceSkill.Next = 0;

        exit(true);
    end;

    procedure QualifiedForServiceItemLine(var ServiceItemLine: Record "Service Item Line"; ResourceNo: Code[20]): Boolean
    var
        ResourceSkill: Record "Resource Skill";
    begin
        case true of
            ServiceItemLine."Service Item No." <> '':
                if not
                   ResourceQualified(
                     ResourceNo,
                     ResourceSkill.Type::"Service Item",
                     ServiceItemLine."Service Item No.")
                then
                    exit(false);
            ServiceItemLine."Item No." <> '':
                if not
                   ResourceQualified(
                     ResourceNo,
                     ResourceSkill.Type::Item,
                     ServiceItemLine."Item No.")
                then
                    exit(false);
            ServiceItemLine."Service Item Group Code" <> '':
                if not
                   ResourceQualified(
                     ResourceNo,
                     ResourceSkill.Type::"Service Item Group",
                     ServiceItemLine."Service Item Group Code")
                then
                    exit(false);
        end;
        exit(true);
    end;

    procedure CheckServiceItemLineFinished(var ServHeader: Record "Service Header"; ServiceItemLineNo: Integer)
    var
        ServiceItemLine: Record "Service Item Line";
        RepairStatus: Record "Repair Status";
    begin
        with ServiceItemLine do
            if Get(ServHeader."Document Type", ServHeader."No.", ServiceItemLineNo) then
                if "Repair Status Code" <> '' then begin
                    RepairStatus.Get("Repair Status Code");
                    if RepairStatus.Finished then
                        Error(Text004, "Line No.", FieldCaption("Repair Status Code"), "Repair Status Code");
                end;
    end;

    procedure SetServOrderAllocStatus(var ServHeader: Record "Service Header")
    var
        ServOrderAlloc: Record "Service Order Allocation";
        ServOrderAlloc2: Record "Service Order Allocation";
    begin
        ServOrderAlloc.Reset();
        ServOrderAlloc.SetCurrentKey("Document Type", "Document No.");
        ServOrderAlloc.SetRange("Document Type", ServHeader."Document Type");
        ServOrderAlloc.SetRange("Document No.", ServHeader."No.");
        if ServOrderAlloc.Find('-') then
            repeat
                ServOrderAlloc2 := ServOrderAlloc;
                ServOrderAlloc2.Posted := true;
                if ServOrderAlloc2.Status = ServOrderAlloc2.Status::Active then
                    ServOrderAlloc2.Status := ServOrderAlloc2.Status::Finished;
                ServOrderAlloc2.Modify();
            until ServOrderAlloc.Next = 0;
    end;

    procedure SetServLineAllocStatus(var ServLine: Record "Service Line")
    var
        ServOrderAlloc: Record "Service Order Allocation";
        ServOrderAlloc2: Record "Service Order Allocation";
    begin
        if (ServLine."Service Item Line No." = 0) or (ServLine."Qty. to Ship" = 0) then
            exit;
        ServOrderAlloc.Reset();
        ServOrderAlloc.SetCurrentKey("Document Type", "Document No.");
        ServOrderAlloc.SetRange("Document Type", ServLine."Document Type");
        ServOrderAlloc.SetRange("Document No.", ServLine."Document No.");
        ServOrderAlloc.SetRange("Service Item Line No.", ServLine."Service Item Line No.");
        if ServOrderAlloc.Find('-') then
            repeat
                ServOrderAlloc2 := ServOrderAlloc;
                ServOrderAlloc2.Posted := true;
                ServOrderAlloc2.Modify();
            until ServOrderAlloc.Next = 0;
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeCancelAllocation(var ServOrderAllocation: Record "Service Order Allocation"; var IsHandled: Boolean);
    begin
    end;


    [IntegrationEvent(false, false)]
    local procedure OnBeforeCreateAllocationEntry(DocumentType: Integer; DocumentNo: Code[20]; ServItemLineNo: Integer; ServItemNo: Code[20]; ServSerialNo: Code[50]; var IsHandled: Boolean);
    begin
    end;
}

