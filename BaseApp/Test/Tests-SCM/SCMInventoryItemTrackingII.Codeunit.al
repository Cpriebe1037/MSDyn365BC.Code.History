codeunit 137261 "SCM Inventory Item Tracking II"
{
    Subtype = Test;
    TestPermissions = Disabled;

    trigger OnRun()
    begin
        // [FEATURE] [Item Tracking] [SCM]
        isInitialized := false;
    end;

    var
        Assert: Codeunit Assert;
        LibraryTestInitialize: Codeunit "Library - Test Initialize";
        LibraryERM: Codeunit "Library - ERM";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryItemTracking: Codeunit "Library - Item Tracking";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibrarySales: Codeunit "Library - Sales";
        LibraryManufacturing: Codeunit "Library - Manufacturing";
        LibraryUtility: Codeunit "Library - Utility";
        LibraryVariableStorage: Codeunit "Library - Variable Storage";
        LibraryWarehouse: Codeunit "Library - Warehouse";
        LibraryPlanning: Codeunit "Library - Planning";
        LibraryRandom: Codeunit "Library - Random";
        isInitialized: Boolean;
        AvailabilityWarning: Label 'There are availability warnings on one or more lines.';
        DeleteItemTrackingCodeError: Label 'You cannot delete %1 %2 because it is used on one or more items.', Comment = '%1:FieldCaption1,%2:Value1';
        MultipleExpirDateError: Label 'There are multiple expiration dates registered for lot %1.';
        NegativeSelectedQuantityError: Label 'The value must be greater than or equal to 0. Value: -%1.';
        SelectedQuantityError: Label 'You cannot select more than';
        SerialLotConfirmMessage: Label 'Do you want to reserve specific tracking numbers?';
        PickCreated: Label 'Number of Invt. Pick activities created: 1 out of a total of 1.';
        ReservEntryError: Label 'There is no Reservation Entry within the filter.';
        AssignSerialNoStatus: Label 'Assign Serial No must be TRUE.';
        ExistingSalesLnITError: Label 'Item tracking is defined for item %1 in the Sales Line.';
        WrongSerialNoErr: Label 'Serial No is wrong.';
        TrackingOption: Option AssignSerialNo,AssignLotNo,VerifyLotNo,EditValue,SelectEntries,UpdateQtyToInvoice,AssignLotNo2,AssignQty,ReSelectEntries,AssignMoreThanPurchasedQty,SetNewLotNo,EditSNValue,SetNewSN,SetLotAndSerial,CheckExpDateControls;
        TheLotNoInfoDoesNotExistErr: Label 'The Lot No. Information does not exist. Identification fields and values:';
        TheSerialNoInfoDoesNotExistErr: Label 'The Serial No. Information does not exist. Identification fields and values:';
        LotNoBySNNotFoundErr: Label 'A lot number could not be found for serial number';
        QtyToInvoiceDoesNotMatchItemTrackingErr: Label 'The quantity to invoice does not match the quantity defined in item tracking.';

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler,EnterQuantityToCreatePageHandler')]
    [Scope('OnPrem')]
    procedure PartialInvoicePurchaseWithIT()
    var
        Item: Record Item;
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
    begin
        // [FEATURE] [Purchase Order]
        // [SCENARIO] Fully received purchase order with serial no. tracked item cannot be partially invoiced if "Qty. to Invoice" on the purchase line does not match "Qty. to Invoice" in item tracking.
        Initialize;

        // [GIVEN] Create Purchase Order with Item with Serial Specific Item Tracking and Post Purchase Order Receipt.
        CreateTrackedItem(Item, '', LibraryUtility.GetGlobalNoSeriesCode, CreateItemTrackingCode(false, true, false));
        CreatePurchaseOrder(PurchaseLine, Item."No.", LibraryRandom.RandInt(20));
        AssignSerialNoAndReceivePurchaseOrder(PurchaseHeader, PurchaseLine);
        PurchaseLine.Find;

        // [WHEN] Post Partial Invoice from Purchase Order.
        asserterror LibraryPurchase.PostPurchaseDocument(PurchaseHeader, false, true);

        // [THEN] "The quantity to invoice does not match item tracking" error message is raised.
        Assert.ExpectedError(QtyToInvoiceDoesNotMatchItemTrackingErr);
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler,EnterQuantityToCreatePageHandler')]
    [Scope('OnPrem')]
    procedure ErrorForDeleteItemTrackingCode()
    var
        Item: Record Item;
        ItemJournalLine: Record "Item Journal Line";
        ItemTrackingCode: Record "Item Tracking Code";
    begin
        // Verify Error while Deleting Item Tracking Code after creating inventory with Item Tracking.

        // Setup: Create Item Journal Line with Serial Specific Item Tracking and post.
        Initialize;
        CreateTrackedItem(Item, '', LibraryUtility.GetGlobalNoSeriesCode, CreateItemTrackingCode(false, true, false));
        CreateItemJournalLine(ItemJournalLine, Item."No.", '', '', LibraryRandom.RandInt(10));  // Take random for Quantity and used blank for Location and Bin Code.
        LibraryVariableStorage.Enqueue(TrackingOption::AssignSerialNo);  // Enqueue value for ItemTrackingLinesPageHandler.
        ItemJournalLine.OpenItemTrackingLines(false);
        LibraryInventory.PostItemJournalLine(ItemJournalLine."Journal Template Name", ItemJournalLine."Journal Batch Name");
        ItemTrackingCode.Get(Item."Item Tracking Code");

        // Exercise: Delete Item Tracking Code.
        asserterror ItemTrackingCode.Delete(true);

        // Verify: Verify error message while Deleting Item Tracking Code.
        Assert.ExpectedError(StrSubstNo(DeleteItemTrackingCodeError, Item.FieldCaption("Item Tracking Code"), ItemTrackingCode.Code));
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler,ConfirmHandler')]
    [Scope('OnPrem')]
    procedure LotNoOnPurchaseOrderFromCarryOutActMsg()
    var
        Item: Record Item;
        SalesLine: Record "Sales Line";
        Vendor: Record Vendor;
        LotNo: Variant;
    begin
        // Verify Lot No. in Purchase Order created from Sales Order through Carry Out Action Msg.

        // Setup: Create Item, Location, Vendor and Sales Order with Item Tracking.
        Initialize;
        CreateSetupforSalesOrder(SalesLine, true, false);
        Item.Get(SalesLine."No.");
        LibraryPurchase.CreateVendor(Vendor);
        LibraryVariableStorage.Enqueue(TrackingOption::AssignLotNo);  // Enqueue value for ItemTrackingLinesPageHandler.
        LibraryVariableStorage.Enqueue(AvailabilityWarning);  // Enqueue value for ConfirmHandler.
        SalesLine.OpenItemTrackingLines;
        LibraryVariableStorage.Dequeue(LotNo);

        // Exercise: Generate Purchase Order through Carry Out Action Msg.
        CalcRegenPlanAndCarryOutActionMsg(Item, SalesLine."Location Code", Vendor."No.");

        // Verify: Verify Lot No. in Reservation Entry for generated Purchase Order.
        VerifyPurchaseOrderItemTracking(SalesLine."Location Code", Item."No.", LotNo);
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler,EnterQuantityToCreatePageHandler,ConfirmHandler')]
    [Scope('OnPrem')]
    procedure DeleteSerialNoOnPlanningWorksheet()
    var
        Item: Record Item;
        SalesLine: Record "Sales Line";
    begin
        // Verify Reservation Entry for Deleted Item Tracking on Planning Worksheet.

        // Setup: Create Item, Location, Vendor and Sales Order with Item Tracking.
        Initialize;
        CreateSetupforSalesOrder(SalesLine, false, true);
        Item.Get(SalesLine."No.");
        LibraryVariableStorage.Enqueue(TrackingOption::AssignSerialNo);  // Enqueue value for ItemTrackingLinesPageHandler.
        LibraryVariableStorage.Enqueue(AvailabilityWarning);  // Enqueue value for ConfirmHandler.
        SalesLine.OpenItemTrackingLines;
        LibraryPlanning.CalcRegenPlanForPlanWksh(Item, WorkDate, CalcDate('<CY>', WorkDate));  // Dates based on WORKDATE.

        // Exercise: Delete Item Tracking Lines from Planning Worksheet.
        DeleteItemTrackingLines(SalesLine);

        // Verify: Verify Deleted Item Tracking in Reservation Entry from Planning Worksheet.
        VerifyDeletedItemTracking(SalesLine);
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler,EnterQuantityToCreatePageHandler,ItemTrackingSummaryPageHandler')]
    [Scope('OnPrem')]
    procedure SalesLineErrorWithNegativeSelectedQty()
    var
        Quantity: Decimal;
    begin
        // Verify error while negative values is taken in the Selected Quantity field on Item Tracking Summary page.

        // Setup: Create Item, create and post Purchase Order, create Sales Order.
        Initialize;
        Quantity := LibraryRandom.RandInt(20);  // Take random for Quantity.
        SelectITEntriesOnSalesLine(Quantity, -1, StrSubstNo(NegativeSelectedQuantityError, Quantity));  // -1 for sign factor.
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler,EnterQuantityToCreatePageHandler,ItemTrackingSummaryPageHandler')]
    [Scope('OnPrem')]
    procedure SelectedQtyErrorOnSalesLine()
    begin
        // Verify error for Selected Quantity field on Item Tracking Summary page after creating Sales Order.

        // Setup: Create Item, create and post Purchase Order, create Sales Order.
        Initialize;
        SelectITEntriesOnSalesLine(10 + LibraryRandom.RandInt(10), 1, StrSubstNo(SelectedQuantityError));  // Take random Quantity greater than 1 and 1 for sign factor.
    end;

    local procedure SelectITEntriesOnSalesLine(Quantity: Integer; SignFactor: Integer; ExpectedError: Text[100])
    var
        SalesLine: Record "Sales Line";
    begin
        // Create Item, create and post Purchase Order, create Sales Order.
        SetupSalesAndPurchEntryWithIT(SalesLine, Quantity);
        LibraryVariableStorage.Enqueue(SignFactor * SalesLine.Quantity);

        // Exercise: Assign Item Tracking on Sales Line.
        asserterror SalesLine.OpenItemTrackingLines;

        // Verify: Verify error for Select Quantity on Sales Line.
        Assert.ExpectedError(ExpectedError);
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler,EnterQuantityToCreatePageHandler,ItemTrackingSummaryPageHandler,ItemTrackingListPageHandler,ReservationPageHandler,ConfirmHandler')]
    [Scope('OnPrem')]
    procedure SelectedQtyErrorOnSalesLineWithReserv()
    var
        SalesLine: Record "Sales Line";
        SummaryOption: Option SetQuantity,VerifyQuantity;
    begin
        // Verify error for Selected Quantity field on Item Tracking Summary page after creating Sales Order with Reservation.

        // Setup: Create Item, create and post Purchase Order, create Sales Order.
        Initialize;
        SetupSalesAndPurchEntryWithIT(SalesLine, LibraryRandom.RandInt(10));  // Take random Quantity.
        LibraryVariableStorage.Enqueue(1);  // Enqueue 1 for Quantity as Item Tracking code is Serial Specific for ItemTrackingSummaryPageHandler.

        // Exercise: Assign Item Tracking and Reservation on Sales Line.
        asserterror AssignTrackingAndReserveOnSalesLine(SalesLine, SummaryOption::SetQuantity, SalesLine.Quantity);

        // Verify: Verify error for Select Quantity on Sales Line.
        Assert.ExpectedError(SelectedQuantityError);
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler,EnterQuantityToCreatePageHandler,ItemTrackingSummaryPageHandler,ItemTrackingListPageHandler,ReservationPageHandler,ConfirmHandler')]
    [Scope('OnPrem')]
    procedure SelectedQtyOnSalesLineWithReserv()
    var
        SalesLine: Record "Sales Line";
        SummaryOption: Option SetQuantity,VerifyQuantity;
    begin
        // Verify Selected Quantity on Item Tracking Summary page after creating Sales Order with Reservation.

        // Setup: Create Item, create and post Purchase Order, create Sales Order.
        Initialize;
        SetupSalesAndPurchEntryWithIT(SalesLine, LibraryRandom.RandInt(10));  // Take random Quantity.
        LibraryVariableStorage.Enqueue(1);  // Enqueue 1 for Quantity as Item Tracking code is Serial Specific for ItemTrackingSummaryPageHandler.

        // Exercise: Item Tracking and Reservation on Sales Line.
        AssignTrackingAndReserveOnSalesLine(SalesLine, SummaryOption::VerifyQuantity, 0);

        // Verify: Verify Selected Quantity on Item Tracking Summary page.Verification done in ItemTrackingSummaryPageHandler.
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler,EnterQuantityToCreatePageHandler,ItemTrackingSummaryPageHandler')]
    [Scope('OnPrem')]
    procedure ExpirDateOnItemTrackingSummaryPage()
    var
        SalesLine: Record "Sales Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
        SummaryOption: Option SetQuantity,VerifyQuantity,VerifyExpirationDate;
    begin
        // Verify Expiration Date on Item Tracking Summary page after creating Sales Order.

        // Setup: Create Item, create and post Purchase Order, create Sales Order.
        Initialize;
        SetupSalesAndPurchEntryWithIT(SalesLine, LibraryRandom.RandInt(10));  // Take random Quantity.

        // Enuque values for ItemTrackingLinesPageHandler and ItemTrackingSummaryPageHandler.Taking 1 for Quantity as Item Tracking code is Serial Specific.
        LibraryVariableStorage.Enqueue(1);
        LibraryVariableStorage.Enqueue(TrackingOption::SelectEntries);
        LibraryVariableStorage.Enqueue(SummaryOption::VerifyExpirationDate);
        LibraryVariableStorage.Enqueue(1);
        FindItemLedgerEntry(ItemLedgerEntry, SalesLine."No.");
        LibraryVariableStorage.Enqueue(ItemLedgerEntry."Expiration Date");

        // Exercise: Assign Item Tracking on Sales Line.
        SalesLine.OpenItemTrackingLines;

        // Verify: Verify Expiration Date on Item Tracking Summary page.Verification done in ItemTrackingSummaryPageHandler.
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler,EnterQuantityToCreatePageHandler,ItemTrackingSummaryPageHandler')]
    [Scope('OnPrem')]
    procedure PostSalesOrderWithExpirDateAndIT()
    var
        GeneralPostingSetup: Record "General Posting Setup";
        GLAccount: Record "G/L Account";
        SalesLine: Record "Sales Line";
        SalesInvoiceHeader: Record "Sales Invoice Header";
        DocumentNo: Code[20];
    begin
        // Verify Sales Order is posted successfully created with Item Tracking and Expiration Date.

        // Setup: Create Item, create and post Purchase Order, create Sales Order with Expiration Date and Item Tracking.
        Initialize;
        SetupSalesAndPurchEntryWithIT(SalesLine, LibraryRandom.RandInt(10));  // Take random Quantity.
        GeneralPostingSetup.Get(SalesLine."Gen. Bus. Posting Group", SalesLine."Gen. Prod. Posting Group");
        LibraryERM.FindGLAccount(GLAccount);
        UpdateGeneralLedgerSetup(SalesLine."Gen. Bus. Posting Group", SalesLine."Gen. Prod. Posting Group", GLAccount."No.");
        LibraryVariableStorage.Enqueue(1);
        SalesLine.OpenItemTrackingLines;

        // Exercise: Post Sales Order.
        DocumentNo := PostSalesDocument(SalesLine."Document Type", SalesLine."Document No.", true);

        // Verify: Verify Sales Order has been posted successfully.
        SalesInvoiceHeader.Get(DocumentNo);

        // Tear Down.
        UpdateGeneralLedgerSetup(
          SalesLine."Gen. Bus. Posting Group", SalesLine."Gen. Prod. Posting Group", GeneralPostingSetup."Sales Account");
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler,EnterQuantityToCreatePageHandler,ItemTrackingSummaryPageHandler,MessageHandlerValidateMessage')]
    [Scope('OnPrem')]
    procedure CreateInvPickOnSalesOrderWithIT()
    var
        PurchaseLine: Record "Purchase Line";
        SalesLine: Record "Sales Line";
    begin
        // Verify Message while creating Inventory Pick on Sales Order with Item Tracking.

        // Setup: Create and post Purchase Order, create Sales Order with Item Tracking.
        Initialize;
        PostPurchaseOrderWithLocation(PurchaseLine);
        CreateSalesOrderWithIT(SalesLine, PurchaseLine."No.", PurchaseLine."Location Code", PurchaseLine.Quantity, 1);  // Taking 1 for Quantity as Item Tracking code is Serial Specific.

        // Exercise: Create Inventory Pick on Sales Order.
        CreateInventoryPickOnSalesLine(SalesLine);

        // Verify message that Pick has been created. Verification done in MessageHandlerValidateMessage.
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler,EnterQuantityToCreatePageHandler,ItemTrackingSummaryPageHandler,MessageHandlerValidateMessage')]
    [Scope('OnPrem')]
    procedure ReservEntryErrorAfterPostInvPickOnSalesOrder()
    var
        GLAccount: Record "G/L Account";
        PurchaseLine: Record "Purchase Line";
        SalesLine: Record "Sales Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
        WarehouseActivityHeader: Record "Warehouse Activity Header";
        No: Code[20];
    begin
        // Verify Reservation Entry error if an Inventory Pick on Sales Order is created and posted.

        // Setup: Create and post Purchase Order, create and post Inventory Pick on Sales Order.
        Initialize;
        PostPurchaseOrderWithLocation(PurchaseLine);
        FindItemLedgerEntry(ItemLedgerEntry, PurchaseLine."No.");
        CreateSalesOrderWithIT(SalesLine, PurchaseLine."No.", PurchaseLine."Location Code", PurchaseLine.Quantity / 2, 1);  // Taking partial Quantity and 1 for Quantity as Item Tracking code is Serial Specific.
        LibraryERM.FindGLAccount(GLAccount);
        UpdateGeneralLedgerSetup(SalesLine."Gen. Bus. Posting Group", SalesLine."Gen. Prod. Posting Group", GLAccount."No.");
        No := CreateInventoryPickOnSalesLine(SalesLine);
        WarehouseActivityHeader.Get(WarehouseActivityHeader.Type::"Invt. Pick", No);
        LibraryWarehouse.PostInventoryActivity(WarehouseActivityHeader, true);

        // Exercise.
        asserterror FindReservationEntryForSerialNo(SalesLine."No.", PurchaseLine."Location Code", ItemLedgerEntry."Serial No.");

        // Verify.
        Assert.ExpectedError(ReservEntryError);
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler,EnterQuantityToCreatePageHandler,ItemTrackingSummaryPageHandler')]
    [Scope('OnPrem')]
    procedure SelectedQtyErrorAfterPostInvPickOnSalesOrder()
    var
        PurchaseLine: Record "Purchase Line";
        SalesLine: Record "Sales Line";
    begin
        // Verify error for Selected Quantity field on Item Tracking Summary page after an Inventory Pick on Sales Order is created and posted.

        // Setup:
        Initialize;
        PostWhseRcptAndRegisterPutAway(PurchaseLine);
        CreateWhseShptAndRegisterPick(PurchaseLine);

        // Exercise: Item Tracking and Reservation on Sales Line.
        asserterror CreateSalesOrderWithIT(SalesLine, PurchaseLine."No.", PurchaseLine."Location Code", PurchaseLine.Quantity / 2, 1);  // Taking partial Quantity and 1 for Quantity as Item Tracking code is Serial Specific.

        // Verify: Verify error for Select Quantity on Sales Line.
        Assert.ExpectedError(SelectedQuantityError);
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler,EnterQuantityToCreatePageHandler,ItemTrackingSummaryPageHandler')]
    [Scope('OnPrem')]
    procedure ExpirDateOnILEAfterRegisterPutAway()
    var
        Item: Record Item;
        PurchaseLine: Record "Purchase Line";
        SalesLine: Record "Sales Line";
        ExpirationDate: Date;
    begin
        // Verify Expiration Date on Item Ledger Entry When Put Away is Registered.

        // Setup: Create Purchase Order, post Warehouse Receipt, register Put Away.
        Initialize;
        PostWhseRcptAndRegisterPutAway(PurchaseLine);
        Item.Get(PurchaseLine."No.");
        ExpirationDate := CalcDate(Item."Expiration Calculation", WorkDate);

        // Exercise: Create Sales Order with Item Tracking.
        CreateSalesOrderWithIT(SalesLine, PurchaseLine."No.", PurchaseLine."Location Code", PurchaseLine.Quantity / 2, 1);  // Taking partial Quantity and 1 for Quantity as Item Tracking code is Serial Specific.

        // Verify: Verify Expiration Date on Item Ledger Entry.
        VerifyExpirationDateOnItemLedgerEntry(SalesLine."No.", ExpirationDate);
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler,EnterQuantityToCreatePageHandler,ItemTrackingSummaryPageHandler')]
    [Scope('OnPrem')]
    procedure ExpirDateOnILEAfterRegisterPick()
    var
        Item: Record Item;
        PurchaseLine: Record "Purchase Line";
        SalesLine: Record "Sales Line";
        ExpirationDate: Date;
    begin
        // Verify Expiration Date on Item Ledger Entry When Pick is Registered.

        // Setup: Create Purchase Order, post Warehouse Receipt, Register Put Away, create Warehouse Shipment and register Pick.
        Initialize;
        PostWhseRcptAndRegisterPutAway(PurchaseLine);
        CreateWhseShptAndRegisterPick(PurchaseLine);
        Item.Get(PurchaseLine."No.");
        ExpirationDate := CalcDate(Item."Expiration Calculation", WorkDate);

        // Exercise: Create Sales Order with Item Tracking.
        CreateSalesOrderWithIT(SalesLine, PurchaseLine."No.", PurchaseLine."Location Code", PurchaseLine.Quantity / 2, 0);  // Taking partial Quantity and 0 for Quantity as Item Tracking code is Serial Specific.

        // Verify: Verify Expiration Date on Item Ledger Entry.
        VerifyExpirationDateOnItemLedgerEntry(SalesLine."No.", ExpirationDate);
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler,EnterQuantityToCreatePageHandler,ConfirmHandler,ItemTrackingSummaryPageHandler')]
    [Scope('OnPrem')]
    procedure SelectedQtyErrorWithAssignITManually()
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        Location: Record Location;
        SalesLine: Record "Sales Line";
    begin
        // Verify error for Selected Quantity field on Item Tracking Summary page after assigning Item Tracking manually.

        // Setup: Create and post Purchase Order.
        Initialize;
        LibraryWarehouse.CreateLocationWithInventoryPostingSetup(Location);
        CreatePurchaseOrderWithLocation(PurchaseLine, Location.Code, '');
        AssignSerialNoOnPurchaseOrder(PurchaseHeader, PurchaseLine);
        LibraryPurchase.PostPurchaseDocument(PurchaseHeader, true, false);

        // Create Sales Order and Assign Item Tracking.
        CreateSalesDocument(SalesLine, SalesLine."Document Type"::Order, PurchaseLine."No.", Location.Code, PurchaseLine.Quantity / 2);  // Take partial Quantity.
        LibraryVariableStorage.Enqueue(TrackingOption::AssignSerialNo);  // Enqueue value for ItemTrackingLinesPageHandler.
        LibraryVariableStorage.Enqueue(AvailabilityWarning);
        SalesLine.OpenItemTrackingLines;

        // Exercise: Create another Sales Order and assign Item Tracking.
        asserterror CreateSalesOrderWithIT(SalesLine, PurchaseLine."No.", PurchaseLine."Location Code", PurchaseLine.Quantity / 2, 1);  // Taking partial Quantity and 0 for Quantity as Item Tracking code is Serial Specific.

        // Verify: Verify error for Selected Quantity field on Item Tracking Summary page.
        Assert.ExpectedError(SelectedQuantityError);
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler,ItemTrackingSummaryPageHandler')]
    [Scope('OnPrem')]
    procedure PostItemReclassJournalWithLotNo()
    var
        ItemJournalLine: Record "Item Journal Line";
    begin
        // Verify Posting of Item Reclass. Journal with Lot Tracked Item.

        // Setup: Create and post Item Journal with Item Tracking, create Reclassification Journal with Item Tracking.
        Initialize;
        CreateAndPostItemJournalLineWithIT(ItemJournalLine);
        CreateItemReclassificationJournal(
          ItemJournalLine, ItemJournalLine."Item No.", ItemJournalLine."Location Code", ItemJournalLine."Bin Code",
          ItemJournalLine.Quantity);

        // Exercise: Post Item Reclass. Journal.
        LibraryInventory.PostItemJournalLine(ItemJournalLine."Journal Template Name", ItemJournalLine."Journal Batch Name");

        // Verify: Verify Location on Warehouse entries.
        VerifyWarehouseEntry(ItemJournalLine);
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler')]
    [Scope('OnPrem')]
    procedure CreateItemReclassJournalWithIT_ExpDateNotVisible()
    var
        ItemJournalLine: Record "Item Journal Line";
        ItemJournalBatch: Record "Item Journal Batch";
    begin
        // When Use Expiration Dates = false, the column is neither shown nor editable on the tracking page in Item Reclassification.

        CreateTrackedItemAndPostItemJournal(ItemJournalLine, false);

        // Setup: Create Item Reclass Line 
        SelectAndClearItemJournalBatch(ItemJournalBatch, ItemJournalBatch."Template Type"::Transfer);
        LibraryInventory.CreateItemJournalLine(
          ItemJournalLine, ItemJournalBatch."Journal Template Name", ItemJournalBatch.Name, ItemJournalLine."Entry Type"::Transfer, ItemJournalLine."Item No.",
          ItemJournalLine.Quantity);
        ItemJournalLine.Validate("Location Code", ItemJournalLine."Location Code");
        ItemJournalLine.Validate("Bin Code", ItemJournalLine."Bin Code");
        ItemJournalLine.Modify(true);
        LibraryVariableStorage.Enqueue(TrackingOption::CheckExpDateControls); // Enqueue value for ItemTrackingLinesPageHandler.
        LibraryVariableStorage.Enqueue(false); // Enqueue value for CheckExpDateControls.
        AssertError ItemJournalLine.OpenItemTrackingLines(true);
        Assert.ExpectedError('The field with ID'); // Invisible fields cannot be tested but the error raised confirms that the field is invisible
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler')]
    [Scope('OnPrem')]
    procedure CreateItemReclassJournalWithIT_ExpDateVisible()
    var
        ItemJournalLine: Record "Item Journal Line";
        ItemJournalBatch: Record "Item Journal Batch";
    begin
        // When Use Expiration Dates = true, the column is shown as editable on the tracking page in Item Reclassification.
        Initialize;

        CreateTrackedItemAndPostItemJournal(ItemJournalLine, true);

        // Setup: Create Item Reclass Line 
        SelectAndClearItemJournalBatch(ItemJournalBatch, ItemJournalBatch."Template Type"::Transfer);
        LibraryInventory.CreateItemJournalLine(
          ItemJournalLine, ItemJournalBatch."Journal Template Name", ItemJournalBatch.Name, ItemJournalLine."Entry Type"::Transfer, ItemJournalLine."Item No.",
          ItemJournalLine.Quantity);
        ItemJournalLine.Validate("Location Code", ItemJournalLine."Location Code");
        ItemJournalLine.Validate("Bin Code", ItemJournalLine."Bin Code");
        ItemJournalLine.Modify(true);
        LibraryVariableStorage.Enqueue(TrackingOption::CheckExpDateControls); // Enqueue value for ItemTrackingLinesPageHandler.
        LibraryVariableStorage.Enqueue(true); // Enqueue value for CheckExpDateControls.
        AssertError ItemJournalLine.OpenItemTrackingLines(true);
        Assert.ExpectedError('The field with ID'); // Invisible fields cannot be tested but the error raised confirms that the field is invisible
    end;

    local procedure CreateTrackedItemAndPostItemJournal(var ItemJournalLine: Record "Item Journal Line"; UseExpirationDates: Boolean)
    var
        Item: Record Item;
        Bin: Record Bin;
        LotNo: Variant;
    begin
        // Setup: Create item that has Use Expiration Dates = UseExpirationDates
        CreateTrackedItem(Item, LibraryUtility.GetGlobalNoSeriesCode, '', CreateItemTrackingCode(true, false, UseExpirationDates));

        // Setup: Post Item Journal with Item Tracking
        CreateLocationWithBin(Bin);
        CreateItemJournalLine(ItemJournalLine, Item."No.", Bin."Location Code", Bin.Code, LibraryRandom.RandInt(10));  // Take random Quantity.
        LibraryVariableStorage.Enqueue(TrackingOption::AssignLotNo);  // Enqueue value for ItemTrackingLinesPageHandler.
        ItemJournalLine.OpenItemTrackingLines(false);
        LibraryInventory.PostItemJournalLine(ItemJournalLine."Journal Template Name", ItemJournalLine."Journal Batch Name");
        LibraryVariableStorage.Dequeue(LotNo);
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler,EnterQuantityToCreateHandlerForSetQuantity')]
    [Scope('OnPrem')]
    procedure PostPartialPurchOrderWithSerialNo()
    var
        Item: Record Item;
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        PurchInvLine: Record "Purch. Inv. Line";
        Quantity: Decimal;
        DocumentNo: Code[20];
    begin
        // Verify Purchase Order is posted partially with Serial Tracked Item.

        // Setup: Create Item, create Purchase Order and Receive partially.
        Initialize;
        CreateTrackedItem(Item, '', LibraryUtility.GetGlobalNoSeriesCode, CreateItemTrackingCode(false, true, false));
        CreatePurchaseOrder(PurchaseLine, Item."No.", 2 * LibraryRandom.RandInt(100));  // Take random Quantity.
        UpdatePurchaseLineAndAssignIT(
          PurchaseLine, PurchaseLine.FieldNo("Qty. to Receive"), PurchaseLine.Quantity / 2, TrackingOption::AssignSerialNo,
          PurchaseLine.Quantity / 2);
        PurchaseHeader.Get(PurchaseLine."Document Type", PurchaseLine."Document No.");
        LibraryPurchase.PostPurchaseDocument(PurchaseHeader, true, false);  // Post Purchase Order as Receive partially.

        // Update Qty to Invoice on Purchase Line.
        Quantity := LibraryRandom.RandInt(PurchaseLine."Quantity Received" - 1);  // Take random Quantity less than Quantity Received.
        PurchaseLine.Get(PurchaseLine."Document Type", PurchaseLine."Document No.", PurchaseLine."Line No.");
        UpdatePurchaseLineAndAssignIT(
          PurchaseLine, PurchaseLine.FieldNo("Qty. to Invoice"), PurchaseLine."Quantity Received" - Quantity,
          TrackingOption::UpdateQtyToInvoice, Quantity);

        // Exercise: Post Purchase Order as Invoice partially.
        DocumentNo := LibraryPurchase.PostPurchaseDocument(PurchaseHeader, false, true);  // Post Purchase Order as Invoice.

        // Verify: Verify Quantity on Posted Purchase Invoice Line.
        PurchInvLine.SetRange("Document No.", DocumentNo);
        PurchInvLine.SetRange("Buy-from Vendor No.", PurchaseLine."Buy-from Vendor No.");
        PurchInvLine.FindFirst;
        PurchInvLine.TestField(Quantity, PurchaseLine."Qty. to Invoice");
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler')]
    [Scope('OnPrem')]
    procedure ExpirDateOnPurchaseOrderWithLotNo()
    var
        Item: Record Item;
        PurchaseLine: Record "Purchase Line";
        LotNo: Variant;
        ExpirationDate: Date;
    begin
        // Verify Expiration Date for Item Tracking if it has already been assigned to Lot No.

        // Setup: Create and post Purchase Order.
        Initialize;
        CreateAndPostPurchaseOrderWithIT(PurchaseLine, CreateAndUpdateItem(false, true), TrackingOption::AssignLotNo);
        LibraryVariableStorage.Dequeue(LotNo);
        Item.Get(PurchaseLine."No.");
        ExpirationDate := CalcDate(Item."Expiration Calculation", WorkDate);

        // Create another Purchase Order.
        CreatePurchaseOrder(PurchaseLine, PurchaseLine."No.", PurchaseLine.Quantity);  // Take random Quantity.
        LibraryVariableStorage.Enqueue(TrackingOption::EditValue);  // Enqueue value for ItemTrackingLinesPageHandler.
        LibraryVariableStorage.Enqueue(LotNo);

        // Exercise: Assign Item Tracking on Purchase Line.
        PurchaseLine.OpenItemTrackingLines;

        // Verify: Verify Expiration Date on Reservation Entry.
        VerifyExpirationDateForItemTracking(PurchaseLine."No.", ExpirationDate);
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler')]
    [Scope('OnPrem')]
    procedure UpdatedExpirDateOnPurchOrder()
    var
        PurchaseLine: Record "Purchase Line";
        LotNo: Variant;
        ExpirationDate: Date;
    begin
        // Verify Expiration date is updated  for Item Tracking if it is updated in Item Ledger Entry.

        // Setup: Create and post Purchase Order and update Expiration Date on Item Ledger Entry.
        Initialize;
        CreateAndPostPurchaseOrderWithIT(PurchaseLine, CreateAndUpdateItem(false, true), TrackingOption::AssignLotNo);
        LibraryVariableStorage.Dequeue(LotNo);
        ExpirationDate := UpdateExpirDateOnILE(PurchaseLine."No.");

        // Exercise: Create Purchase Order and assign Item Tracking.
        CreatePurchaseOrderWithIT(PurchaseLine, PurchaseLine."No.", LotNo);

        // Verify: Verify Expiration Date on Reservation Entry.
        VerifyExpirationDateForItemTracking(PurchaseLine."No.", ExpirationDate);
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler')]
    [Scope('OnPrem')]
    procedure MultipleExpirDateOnPurchOrder()
    var
        PurchaseLine: Record "Purchase Line";
        Item: Record Item;
        LotNo: Variant;
        ExpirationDate: Date;
    begin
        // Verify Expiration Date is not updated on Purchase Line if multiple Expiration dates for the same lot No. exist in Item Ledger Entry.

        // Setup: Create and post Purchase Order having same Lot No. and update Expiration Date on Item Ledger Entry.
        Initialize;
        LotNo := SetupForMultipleExpirDateOnILE(PurchaseLine);
        Item.Get(PurchaseLine."No.");
        ExpirationDate := CalcDate(Item."Expiration Calculation", WorkDate);

        // Exercise: Create Purchase Order.
        CreatePurchaseOrderWithIT(PurchaseLine, PurchaseLine."No.", LotNo);

        // Verify: Verify Expiration Date on Reservation Entry.
        VerifyExpirationDateForItemTracking(PurchaseLine."No.", ExpirationDate);
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler')]
    [Scope('OnPrem')]
    procedure MultipleExpirDateErrorForSameLotNo()
    var
        PurchaseLine: Record "Purchase Line";
        LotNo: Variant;
    begin
        // Verify error while posting Purchase Order if multiple Expiration dates for the same lot No. exist in Item Ledger Entry.

        // Setup: Create and post Purchase Order having same Lot No. and update Expiration Date on Item Ledger Entry.
        Initialize;
        LotNo := SetupForMultipleExpirDateOnILE(PurchaseLine);
        CreatePurchaseOrderWithIT(PurchaseLine, PurchaseLine."No.", LotNo);

        // Exercise.
        asserterror PostPurchaseOrder(PurchaseLine);

        // Verify: Verify error while posting Purchase Order
        Assert.ExpectedError(StrSubstNo(MultipleExpirDateError, LotNo));
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler,ItemTrackingSummaryPageHandler')]
    [Scope('OnPrem')]
    procedure RecalculateQtyOnItemTrackingLinesPage()
    var
        Item: Record Item;
        PurchaseLine: Record "Purchase Line";
        SalesLine: Record "Sales Line";
        SummaryOption: Option SetQuantity,VerifyQuantity,VerifyExpirationDate,AssignQty,SelectEntries,ReSelectEntries;
    begin
        // Recalculate Quantity on Item Tracking Lines Page.

        // Setup: Create and Post Purchase order with Lot No.
        Initialize;
        CreateTrackedItem(
          Item, LibraryUtility.GetGlobalNoSeriesCode, LibraryUtility.GetGlobalNoSeriesCode, CreateItemTrackingCode(true, false, false));
        CreateAndPostPurchaseOrderWithIT(PurchaseLine, Item."No.", TrackingOption::AssignLotNo2);
        CreateSalesDocument(
          SalesLine, SalesLine."Document Type"::Order, Item."No.", '', (PurchaseLine.Quantity - LibraryRandom.RandInt(10)));  // Random Sales Quantity less than Purchase Quantity for test case.
        EnqueueQuantityForReselectEntries(
          TrackingOption::ReSelectEntries, SummaryOption::SelectEntries, SummaryOption::ReSelectEntries,
          PurchaseLine.Quantity - SalesLine.Quantity, 0, SalesLine.Quantity);

        // Exercise: Open Item Tracking Lines Page.
        SalesLine.OpenItemTrackingLines;

        // Verify: Verify Enqueue Quantity values on Item Tracking Summary Page Handler.
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler,ItemTrackingSummaryPageHandler')]
    [Scope('OnPrem')]
    procedure RecalculateQtyOnITLinesPageWithMoreQtythanPurchase()
    var
        Item: Record Item;
        PurchaseLine: Record "Purchase Line";
        SalesLine: Record "Sales Line";
        QuantityBase: Decimal;
        SummaryOption: Option SetQuantity,VerifyQuantity,VerifyExpirationDate,AssignQty,SelectEntries,ReSelectEntries;
    begin
        // Recalculate Quantity on Sales Order Item Tracking Lines Page With More Quantity than Purchase Quantity.

        // Setup: Create and Post Purchase order with Lot No,Create Sales order,Assign Lot.
        Initialize;
        CreateTrackedItem(
          Item, LibraryUtility.GetGlobalNoSeriesCode, LibraryUtility.GetGlobalNoSeriesCode, CreateItemTrackingCode(true, false, false));
        CreateAndPostPurchaseOrderWithIT(PurchaseLine, Item."No.", TrackingOption::AssignLotNo2);
        CreateSalesDocument(SalesLine, SalesLine."Document Type"::Order, Item."No.", '', (PurchaseLine.Quantity - 1));  // Sales Quantity less than Purchase Quantity for test case.
        QuantityBase := LibraryRandom.RandInt(10) + PurchaseLine.Quantity;  // Take Random Quantity Greater than Purchase Quantity.
        LibraryVariableStorage.Enqueue(TrackingOption::AssignMoreThanPurchasedQty);  // Enqueue value for ItemTrackingLinesPageHandler.
        LibraryVariableStorage.Enqueue(SummaryOption::SelectEntries);  // Enqueue value for ItemTrackingSummaryPageHandler.
        LibraryVariableStorage.Enqueue(QuantityBase);  // Enqueue Quantity Base for ItemTrackingLinesPageHandler.

        // Enqueue value for ItemTrackingSummaryPageHandler.
        LibraryVariableStorage.Enqueue(SummaryOption::ReSelectEntries);
        LibraryVariableStorage.Enqueue(PurchaseLine.Quantity - QuantityBase);
        LibraryVariableStorage.Enqueue(0);
        LibraryVariableStorage.Enqueue(QuantityBase);

        // Exercise: Open Item Tracking Lines Page.
        SalesLine.OpenItemTrackingLines;

        // Verify: Verify Enqueue Quantity values on Item Tracking Summary Page Handler.
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler,ItemTrackingSummaryPageHandler')]
    [Scope('OnPrem')]
    procedure RecalculateQtyOnPartiallyAssignedITLinesPage()
    var
        Item: Record Item;
        PurchaseLine: Record "Purchase Line";
        SalesLine: Record "Sales Line";
        QuantityBase: Variant;
        QtyBase: Decimal;
        SummaryOption: Option SetQuantity,VerifyQuantity,VerifyExpirationDate,AssignQty,SelectEntries,ReSelectEntries;
    begin
        // Recalculate Quantity on Partially Assigned Item Tracking Lines Page.

        // Setup: Create and Post Purchase order,Create Sales Order Assign Lot.
        Initialize;
        CreateTrackedItem(
          Item, LibraryUtility.GetGlobalNoSeriesCode, LibraryUtility.GetGlobalNoSeriesCode, CreateItemTrackingCode(true, false, false));
        CreateAndPostPurchaseOrderWithIT(PurchaseLine, Item."No.", TrackingOption::AssignLotNo2);
        CreateSalesDocument(
          SalesLine, SalesLine."Document Type"::Order, Item."No.", '', (PurchaseLine.Quantity - LibraryRandom.RandInt(10)));  // Take Random Quantity.
        LibraryVariableStorage.Enqueue(TrackingOption::AssignQty);  // Enqueue value for ItemTrackingLinesPageHandler.
        SalesLine.OpenItemTrackingLines;
        LibraryVariableStorage.Dequeue(QuantityBase);
        QtyBase := QuantityBase;
        EnqueueQuantityForReselectEntries(
          TrackingOption::ReSelectEntries, SummaryOption::SelectEntries, SummaryOption::ReSelectEntries,
          PurchaseLine.Quantity - SalesLine.Quantity, QtyBase, SalesLine.Quantity - QtyBase);
        // Enqueue value for ItemTrackingLinesPageHandler,ItemTrackingSummaryPageHandler.

        // Exercise: Open Item Tracking Lines Page.
        SalesLine.OpenItemTrackingLines;

        // Verify: Verify Enqueue Quantity values on Item Tracking Summary Page Handler.
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler,EnterQuantityToCreatePageHandler,ConfirmHandler')]
    [Scope('OnPrem')]
    procedure AssignItemTrackingNoToSupplyOrderWithDemand()
    var
        Item: Record Item;
        Location: Record Location;
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        SalesLine: Record "Sales Line";
    begin
        // Assign Item Tracking Number to Purchase Order With Demand.

        // Setup: Create Sales order and Assign Serial Number, Create Purchase Order and Assign Serial No.
        Initialize;
        CreateTrackedItem(
          Item, LibraryUtility.GetGlobalNoSeriesCode, LibraryUtility.GetGlobalNoSeriesCode, CreateItemTrackingCode(false, true, false));
        LibraryWarehouse.CreateLocation(Location);
        CreateSalesDocument(SalesLine, SalesLine."Document Type"::Order, Item."No.", Location.Code, LibraryRandom.RandInt(10));  // Take random for Quantity.
        LibraryVariableStorage.Enqueue(TrackingOption::AssignSerialNo);  // Enqueue value for ItemTrackingLinesPageHandler.
        LibraryVariableStorage.Enqueue(AvailabilityWarning);  // Enqueue value for ConfirmHandler.
        SalesLine.OpenItemTrackingLines;
        CreatePurchaseOrder(PurchaseLine, Item."No.", LibraryRandom.RandInt(10));  // Take Random Quantity.
        LibraryVariableStorage.Enqueue(TrackingOption::AssignSerialNo);  // Enqueue value for ItemTrackingLinesPageHandler.
        LibraryVariableStorage.Enqueue(AvailabilityWarning);  // Enqueue value for ConfirmHandler.
        PurchaseLine.OpenItemTrackingLines;
        PurchaseHeader.Get(PurchaseLine."Document Type"::Order, PurchaseLine."Document No.");

        // Exercise: Post Purchase Order.
        LibraryPurchase.PostPurchaseDocument(PurchaseHeader, true, false);

        // Verify: Verify Purchase Receipt.
        VerifyPurchRcpt(PurchaseHeader."No.");
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler')]
    [Scope('OnPrem')]
    procedure AssignItemTrackingNoToSupplyOrderWithoutDemand()
    var
        Item: Record Item;
        PurchaseLine: Record "Purchase Line";
    begin
        // Assign Item Tracking Number to Purchase Order without Demand.

        // Setup: Create Purchase order.
        Initialize;
        CreateTrackedItem(
          Item, LibraryUtility.GetGlobalNoSeriesCode, LibraryUtility.GetGlobalNoSeriesCode, CreateItemTrackingCode(false, true, false));
        CreatePurchaseOrder(PurchaseLine, Item."No.", LibraryRandom.RandIntInRange(10, 20));  // Take Random Quantity.
        LibraryVariableStorage.Enqueue(TrackingOption::AssignLotNo2);  // Enqueue value for ItemTrackingLinesPageHandler.

        // Exercise: Open Item Tracking Lines Page.
        PurchaseLine.OpenItemTrackingLines;

        // Verify: Item Tracking Page run without Availability Warning Error.
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler,EnterQuantityToCreatePageHandler')]
    [Scope('OnPrem')]
    procedure AssignSerialNoToSalesRetOrd()
    var
        SalesLine: Record "Sales Line";
    begin
        // Verify Generated Assign Serial No on on Item Tracking Lines Page for Sales Return Order.

        // Setup: Create Sales Return Order, assign Serial No with Item Tracking.
        Initialize;
        CreateSalesRetOrdWithIT(SalesLine);

        // Exercise: Assign Serial Numbers to Item tracking Lines.
        SalesLine.OpenItemTrackingLines;

        // Verify: Verify Serial No Lines generated on the ItemTrackingLinesPageHandler.
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler,EnterQuantityToCreatePageHandler')]
    [Scope('OnPrem')]
    procedure DeleteSalesCrMemoLnWithITLnError()
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
    begin
        // Verify Error while deleting Sales Credit Memo Line with Item tracking lines generated with Get Return Receipt Lines.

        // Setup: Create Sales Return Order, assign Serial No with Item Tracking, create Credit Memo with Get Return Receipt Lines.
        Initialize;
        CreateSalesRetOrdWithIT(SalesLine);
        SalesLine.OpenItemTrackingLines;
        PostSalesDocument(SalesLine."Document Type", SalesLine."Document No.", false);
        CreateSalesCreditMemo(SalesHeader, SalesLine."No.", SalesLine."Sell-to Customer No.");
        FindSalesLine(SalesLine, SalesHeader."Document Type", SalesHeader."No.");

        // Exercise: Delete Credit Memo Line.
        asserterror SalesLine.DeleteAll(true);

        // Verify: Verify Error on deleting Sales Credit Memo Line.
        Assert.ExpectedError(StrSubstNo(ExistingSalesLnITError, SalesLine."No."));
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler,EnterQuantityToCreateHandlerForSetQuantityAssignLot')]
    [Scope('OnPrem')]
    procedure NoSNWhseTrackingPurchOrder()
    var
        WarehouseReceiptLine: Record "Warehouse Receipt Line";
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        Item: Record Item;
        PurchQuantity: Decimal;
    begin
        // [FEATURE] [Item Tracking] [Warehouse] [Purchase]
        // [SCENARIO] Check that warehouse entries contain empty Serial No, if warehouse tracking only enabled for Lot.

        // [GIVEN] Item with Lot Warehouse Tracking, Serial Purchase Inbound Tracking, but no Serial Warehouse Tracking.
        Initialize;
        CreateWhseLotSpecificTrackedItem(Item, true);
        PurchQuantity := LibraryRandom.RandIntInRange(1, 10);

        // [GIVEN] Create Purchase Order, Location with receive/ship required.
        CreatePurchOrderWithLocation(PurchaseLine, CreateLocationWithReceiveShipRequired, Item."No.", PurchQuantity);

        PurchaseHeader.Get(PurchaseLine."Document Type", PurchaseLine."Document No.");
        LibraryPurchase.ReleasePurchaseDocument(PurchaseHeader);

        // [GIVEN] Create Warehouse Receipt from Purchase order, assign Serial and Lot Nos.
        LibraryWarehouse.CreateWhseReceiptFromPO(PurchaseHeader);
        with WarehouseReceiptLine do begin
            SetRange("Source Document", "Source Document"::"Purchase Order");
            SetRange("Source No.", PurchaseHeader."No.");
            FindFirst;
            LibraryVariableStorage.Enqueue(TrackingOption::AssignSerialNo); // Enqueue for ItemTrackingPageHandler.
            LibraryVariableStorage.Enqueue(PurchQuantity); // Enqueue for EnterQuantityToCreateHandlerForSetQuantityAssignLot.
            OpenItemTrackingLines;
        end;

        // [WHEN] Post Warehouse Receipt.
        PostWarehouseReceipt(WarehouseReceiptLine."Source Document"::"Purchase Order", PurchaseHeader."No.");

        // [THEN] Warehouse Entries have empty "Serial No."
        VerifyWarehouseEntriesSN(Item."No.", '');
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler')]
    [Scope('OnPrem')]
    procedure PostItemReclassJournalWithInboundLotInfo()
    var
        Item: Record Item;
        ItemJournalLine: Record "Item Journal Line";
        LotNo: Code[20];
        NewLotNo: Code[20];
    begin
        // [FEATURE] [Item Tracking] [Lot No. Info]
        // [SCENARIO 380704] It should not be allowed to post item reclassification journal with a lot that does not have lot information if inbound lot info must exists in tracking code.
        Initialize;

        // [GIVEN] Assign item tracking code that must have inbound lot info to item "I".
        CreateItemInboundLotInfoMustExist(Item);

        // [GIVEN] Stock inventory with lot no. = "L1".
        LotNo := CreateItemWarehouseInventoryWithLotInfo(ItemJournalLine, Item."No.");

        // [GIVEN] Create item reclassification journal line. Set New "Lot No." = "L2". Lot "L2" does not have lot information.
        NewLotNo := LibraryUtility.GenerateGUID + LibraryUtility.GenerateGUID;
        CreateItemReclassificationJournalLineWithTrackingAttribute(
          ItemJournalLine, ItemJournalLine."Item No.", ItemJournalLine."Location Code",
          ItemJournalLine.Quantity, TrackingOption::SetNewLotNo, LotNo, NewLotNo);

        // [WHEN] Post Item Reclassification Journal
        asserterror LibraryInventory.PostItemJournalLine(ItemJournalLine."Journal Template Name", ItemJournalLine."Journal Batch Name");

        // [THEN] Error 'The Lot No. Information does not exist.' occurs.
        Assert.ExpectedError(TheLotNoInfoDoesNotExistErr);
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler')]
    [Scope('OnPrem')]
    procedure PostItemReclassJournalWithInboundSNInfo()
    var
        Item: Record Item;
        ItemJournalLine: Record "Item Journal Line";
        SN: Code[20];
        NewSN: Code[20];
    begin
        // [FEATURE] [Item Tracking] [Serial No. Info]
        // [SCENARIO 380704] It should not be allowed to post item reclassification journal with a serial no. that does not have serial no. information if inbound serial no. info must exists in tracking code.
        Initialize;

        // [GIVEN] Assign item tracking code that must have inbound serial no. info to item "I".
        CreateItemInboundSNInfoMustExist(Item);

        // [GIVEN] Stock inventory with serial no. = "S1".
        SN := CreateItemWarehouseInventoryWithSNInfo(ItemJournalLine, Item."No.");

        // [GIVEN] Create item reclassification journal line. Set New "Serial No." = "S2". Serial No. "S2" does not have serial no. information.
        NewSN := LibraryUtility.GenerateGUID + LibraryUtility.GenerateGUID;
        CreateItemReclassificationJournalLineWithTrackingAttribute(
          ItemJournalLine, ItemJournalLine."Item No.", ItemJournalLine."Location Code",
          ItemJournalLine.Quantity, TrackingOption::SetNewSN, SN, NewSN);

        // [WHEN] Post Item Reclassification Journal
        asserterror LibraryInventory.PostItemJournalLine(ItemJournalLine."Journal Template Name", ItemJournalLine."Journal Batch Name");

        // [THEN] Error 'The Serial No. Information does not exist.' occurs.
        Assert.ExpectedError(TheSerialNoInfoDoesNotExistErr);
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    [Scope('OnPrem')]
    procedure UpdateInventoryPutAwayLotSerialPurchase()
    var
        WarehouseActivityLine: Record "Warehouse Activity Line";
        SNo: Code[20];
        LNo: Code[20];
    begin
        // [FEATURE] [Inventory Put-Away] [Purchase]
        // [SCENARIO 213968] No error occurs when input new unregistred yet in the system values of "Lot No." and "Serial No." in "Warehouse Activity Line" for Purchase Order for item with Item Tracking Code which requires Lot and Serial tracking
        Initialize;

        // [GIVEN] Inventory Put-Away Line "WAL" for item with Item Tracking Code which requires Lot and Serial tracking, also for Warehouse
        CreateInvtPutawayWithLotSNTrackingItemPurchase(WarehouseActivityLine);

        LNo := LibraryUtility.GenerateGUID;
        SNo := LibraryUtility.GenerateGUID;

        // [WHEN] Update "Lot No." and "Serial No." by values "LN" and "SN" in "WAL"
        UpdateLotSerialNoInWarehouseActivityLine(WarehouseActivityLine, LNo, SNo);

        // [THEN] No error occurs, "WAL"."Lot No." = "LN", "WAL"."Serial No." = "SN"
        WarehouseActivityLine.TestField("Lot No.", LNo);
        WarehouseActivityLine.TestField("Serial No.", SNo);
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    [Scope('OnPrem')]
    procedure UpdateInventoryPutAwayLotSerialProduction()
    var
        WarehouseActivityLine: Record "Warehouse Activity Line";
        SNo: Code[20];
        LNo: Code[20];
    begin
        // [FEATURE] [Inventory Put-Away] [Production]
        // [SCENARIO 213968] No error occurs when input new unregistred yet in the system values of "Lot No." and "Serial No." in "Warehouse Activity Line" for Production Order for item with Item Tracking Code which requires Lot and Serial tracking
        Initialize;

        // [GIVEN] Inventory Put-Away Line "WAL" for item with Item Tracking Code which requires Lot and Serial tracking, also for Warehouse
        CreateInvtPutawayWithLotSNTrackingItemProduction(WarehouseActivityLine);

        LNo := LibraryUtility.GenerateGUID;
        SNo := LibraryUtility.GenerateGUID;

        // [WHEN] Update "Lot No." and "Serial No." by values "LN" and "SN" in "WAL"
        UpdateLotSerialNoInWarehouseActivityLine(WarehouseActivityLine, LNo, SNo);

        // [THEN] No error occurs, "WAL"."Lot No." = "LN", "WAL"."Serial No." = "SN"
        WarehouseActivityLine.TestField("Lot No.", LNo);
        WarehouseActivityLine.TestField("Serial No.", SNo);
    end;

    [Test]
    [HandlerFunctions('MessageHandler,ItemTrackingLinesPageHandler')]
    [Scope('OnPrem')]
    procedure UpdateInventoryPickLotSerialSales()
    var
        WarehouseActivityLine: Record "Warehouse Activity Line";
    begin
        // [FEATURE] [Inventory Pick]
        // [SCENARIO 213968] Error occurs when try to update "Serial No." by value which hasn't corresponding Lot in "Warehouse Activity Line" for Sales Order for item with Item Tracking Code which requires Lot and Serial tracking
        Initialize;

        // [GIVEN] Inventory Pick Line "WAL" for item with Item Tracking Code which requires Lot and Serial tracking, also for Warehouse
        CreateInvtPickWithLotSNTrackingItem(WarehouseActivityLine);

        // [WHEN] Try to update "Lot No." and "Serial No." in "WAL" by new values unregistred in the system
        asserterror
          UpdateLotSerialNoInWarehouseActivityLine(WarehouseActivityLine, LibraryUtility.GenerateGUID, LibraryUtility.GenerateGUID);

        // [THEN] The error 'There is no Entry Summary within the filter' occurs
        Assert.ExpectedError(LotNoBySNNotFoundErr);
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesExpiredLotPageHandler')]
    [Scope('OnPrem')]
    procedure UI_DateFilterUntilWorkDateDefinedByDefaultOnLotNoInformationListPage()
    var
        Item: Record Item;
        LotNoInformationList: TestPage "Lot No. Information List";
        LotNo: Code[20];
    begin
        // [FEATURE] [Item Tracking] [Lot No. Info] [UI]
        // [SCENARIO 338232] The "Date Filter" defines until work date by default when "Lot No. Information List" page opens

        Initialize;

        // [GIVEN] Item with "Lot No." tracking
        CreateItemInboundLotInfoMustExist(Item);
        LotNo := CreateLotNoInformation(Item."No.");

        // [GIVEN] Positive adjustment of Item with Lot Tracking. Work Date = 05.01.2017
        PostItemJournalWithTracking(Item."No.", LotNo);

        // [WHEN] Open "Lot No. Information List" page for Item with "Lot No." tracking
        LotNoInformationList.OpenEdit;
        LotNoInformationList.GotoKey(Item."No.", '', LotNo);

        // [THEN] "Date Filter" is "01.01.0000..05.01.2017"
        Assert.AreEqual(
          LotNoInformationList.FILTER.GetFilter("Date Filter"),
          StrSubstNo('..%1', WorkDate), 'Incorrect Date Filter');
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesExpiredSerialNoPageHandler')]
    [Scope('OnPrem')]
    procedure UI_DateFilterUntilWorkDateDefinedByDefaultOnSerialNoInformationListPage()
    var
        Item: Record Item;
        SerialNoInformationList: TestPage "Serial No. Information List";
        SerialNo: Code[20];
    begin
        // [FEATURE] [Item Tracking] [Lot No. Info] [UI]
        // [SCENARIO 338232] The "Date Filter" defines until work date by default when "Serial No. Information List" page opens

        Initialize;

        // [GIVEN] Item with "Serial No. No." tracking
        CreateItemInboundSNInfoMustExist(Item);
        SerialNo := CreateSNInformation(Item."No.");

        // [GIVEN] Positive adjustment of Item with Serial No. Tracking. Work Date = 05.01.2017
        PostItemJournalWithTracking(Item."No.", SerialNo);

        // [WHEN] Open "Serial No. Information List" page for Item with "Serial No." tracking
        SerialNoInformationList.OpenEdit;
        SerialNoInformationList.GotoKey(Item."No.", '', SerialNo);

        // [THEN] "Date Filter" is "01.01.0000..05.01.2017"
        Assert.AreEqual(
          SerialNoInformationList.FILTER.GetFilter("Date Filter"),
          StrSubstNo('..%1', WorkDate), 'Incorrect Date Filter');
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesExpiredLotPageHandler')]
    [Scope('OnPrem')]
    procedure UI_DateFilterUntilWorkDateDefinedByDefaultOnLotNoInformationCardPage()
    var
        Item: Record Item;
        LotNoInformationCard: TestPage "Lot No. Information Card";
        LotNo: Code[20];
    begin
        // [FEATURE] [Item Tracking] [Lot No. Info] [UI]
        // [SCENARIO 338232] The "Date Filter" defines until work date by default when "Lot No. Information Card" page opens

        Initialize;

        // [GIVEN] Item with "Lot No." tracking
        CreateItemInboundLotInfoMustExist(Item);
        LotNo := CreateLotNoInformation(Item."No.");

        // [GIVEN] Positive adjustment of Item with Lot Tracking. Work Date = 05.01.2017
        PostItemJournalWithTracking(Item."No.", LotNo);

        // [WHEN] Open "Lot No. Information Card" page for Item with "Lot No." tracking
        LotNoInformationCard.OpenEdit;
        LotNoInformationCard.GotoKey(Item."No.", '', LotNo);

        // [THEN] "Date Filter" is "01.01.0000..05.01.2017"
        Assert.AreEqual(
          LotNoInformationCard.FILTER.GetFilter("Date Filter"),
          StrSubstNo('..%1', WorkDate), 'Incorrect Date Filter');
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesExpiredSerialNoPageHandler')]
    [Scope('OnPrem')]
    procedure UI_DateFilterUntilWorkDateDefinedByDefaultOnSerialNoInformationCardPage()
    var
        Item: Record Item;
        SerialNoInformationCard: TestPage "Serial No. Information Card";
        SerialNo: Code[20];
    begin
        // [FEATURE] [Item Tracking] [Lot No. Info] [UI]
        // [SCENARIO 338232] The "Date Filter" defines until work date by default when "Serial No. Information Card" page opens

        Initialize;

        // [GIVEN] Item with "Serial No. No." tracking
        CreateItemInboundSNInfoMustExist(Item);
        SerialNo := CreateSNInformation(Item."No.");

        // [GIVEN] Positive adjustment of Item with Serial No. Tracking. Work Date = 05.01.2017
        PostItemJournalWithTracking(Item."No.", SerialNo);

        // [WHEN] Open "Serial No. Information Card" page for Item with "Serial No." tracking
        SerialNoInformationCard.OpenEdit;
        SerialNoInformationCard.GotoKey(Item."No.", '', SerialNo);

        // [THEN] "Date Filter" is "01.01.0000..05.01.2017"
        Assert.AreEqual(
          SerialNoInformationCard.FILTER.GetFilter("Date Filter"),
          StrSubstNo('..%1', WorkDate), 'Incorrect Date Filter');
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    [Scope('OnPrem')]
    procedure FinalizingPostingPartiallyPutAwayForOutputWithItemTracking()
    var
        Location: Record Location;
        Item: Record Item;
        ProductionOrder: Record "Production Order";
        ProdOrderLine: Record "Prod. Order Line";
        WhseActivHeader: Record "Warehouse Activity Header";
        Qty: Decimal;
    begin
        // [FEATURE] [Production Order] [Output] [Inventory Put-away]
        // [SCENARIO 333316] Posting inventory put-away for production output that has been already partially put-away with another lot.
        Initialize;
        Qty := LibraryRandom.RandIntInRange(100, 200);

        // [GIVEN] Location "L" with enabled put-away.
        // [GIVEN] Lot-tracked item "I".
        Location.Get(CreatePutawayPickLocation);
        CreateWhseLotSpecificTrackedItem(Item, true);

        // [GIVEN] Released production order for item "I" on location "L". Quantity = 100.
        CreateAndRefreshProductionOrderOnLocation(ProductionOrder, Location.Code, Item."No.", Qty);
        FindProdOrderLine(ProdOrderLine, ProductionOrder);

        // [GIVEN] Create inventory put-away, assign lot no. = "L1", quantity = 50 and post.
        CreateInvtPutAwayForProdOrder(WhseActivHeader, ProdOrderLine, Qty / 2);
        LibraryWarehouse.PostInventoryActivity(WhseActivHeader, true);

        // [GIVEN] Delete the partially posted inventory put-away.
        WhseActivHeader.Delete(true);

        // [GIVEN] Create another inventory put-away, assign lot no. = "L2", quantity = 50.
        CreateInvtPutAwayForProdOrder(WhseActivHeader, ProdOrderLine, Qty / 2);

        // [WHEN] Post the second put-away.
        LibraryWarehouse.PostInventoryActivity(WhseActivHeader, true);

        // [THEN] The production output is fully posted.
        ProdOrderLine.Find;
        ProdOrderLine.TestField("Finished Quantity", Qty);
    end;

    [Test]
    [HandlerFunctions('ItemTrackingLinesPageHandler,MessageHandler')]
    [Scope('OnPrem')]
    procedure InventoryPutAwayExpirationCalculationNotBlank()
    var
        Location: Record Location;
        Item: Record Item;
        Bin: Record Bin;
        PurchaseLine: Record "Purchase Line";
        PurchaseHeader: Record "Purchase Header";
        WhseActivHeader: Record "Warehouse Activity Header";
        WarehouseActivityLine: Record "Warehouse Activity Line";
        WarehouseRequest: Record "Warehouse Request";
        PostedInvtPutAwayLine: Record "Posted Invt. Put-away Line";
        WarehouseEntry: Record "Warehouse Entry";
        ExpDate: Date;
    begin
        // [FEATURE] [Purchase] [Inventory Put-away]
        // [SCENARIO 336704] Expiration date is not blank in Warehouse Entry / Posted Inventory Put-away
        // [SCENARIO 336704] on first Item expiration calculation when posting Inventory put-away for Purchase
        Initialize;

        // [GIVEN] Location "L" with enabled put-away.
        // [GIVEN] Lot-tracked item "I" with "Expiration calculation" = "2Y"
        Location.Get(CreatePutawayPickLocation);
        CreateWhseLotSpecificTrackedItem(Item, false);
        LibraryWarehouse.FindBin(Bin, Location.Code, '', 1);

        // [GIVEN] Released purchase order from 01-01-2022 for item "I" on location "L"
        // [GIVEN] Assign new lot number for tracking of item "I"
        CreatePurchaseOrder(PurchaseLine, Item."No.", 1);
        PurchaseLine.Validate("Location Code", Location.Code);
        PurchaseLine.Modify(true);
        LibraryVariableStorage.Enqueue(TrackingOption::AssignLotNo);  // Enqueue value for ItemTrackingLinesPageHandler.
        PurchaseLine.OpenItemTrackingLines;
        PurchaseHeader.Get(PurchaseLine."Document Type", PurchaseLine."Document No.");
        LibraryPurchase.ReleasePurchaseDocument(PurchaseHeader);
        ExpDate := CalcDate(Item."Expiration Calculation", WorkDate);

        // [GIVEN] Create inventory put-away for purchase order with autofilled quantity to handle
        LibraryWarehouse.CreateInvtPutPickMovement(
          WarehouseRequest."Source Document"::"Purchase Order", PurchaseHeader."No.", true, false, false);
        FindWarehouseActivityLine(
          WarehouseActivityLine, PurchaseHeader."No.", WarehouseActivityLine."Activity Type"::"Invt. Put-away",
          PurchaseLine."Location Code", WarehouseActivityLine."Action Type"::Place);
        WarehouseActivityLine.AutofillQtyToHandle(WarehouseActivityLine);
        WarehouseActivityLine.Validate("Bin Code", Bin.Code);
        WarehouseActivityLine.Modify(true);
        WhseActivHeader.Get(WarehouseActivityLine."Activity Type", WarehouseActivityLine."No.");

        // [WHEN] Post Inventory Put-Away for receipt
        LibraryWarehouse.PostInventoryActivity(WhseActivHeader, false);

        // [THEN] Posted Invt. Put-Away line has expiration date = 01-01-2024
        PostedInvtPutAwayLine.SetRange("Item No.", Item."No.");
        PostedInvtPutAwayLine.FindFirst;
        PostedInvtPutAwayLine.TestField("Expiration Date", ExpDate);

        // [THEN] Warehouse entry for the receipt has expiration date = 01-01-2024
        WarehouseEntry.SetRange("Item No.", Item."No.");
        WarehouseEntry.FindFirst;
        WarehouseEntry.TestField("Expiration Date", ExpDate);
    end;

    local procedure Initialize()
    var
        InventorySetup: Record "Inventory Setup";
        LibraryERMCountryData: Codeunit "Library - ERM Country Data";
    begin
        LibraryTestInitialize.OnTestInitialize(CODEUNIT::"SCM Inventory Item Tracking II");
        // Clear Global variables.
        LibraryVariableStorage.Clear;
        // Lazy Setup.
        if isInitialized then
            exit;
        LibraryTestInitialize.OnBeforeTestSuiteInitialize(CODEUNIT::"SCM Inventory Item Tracking II");

        LibraryERMCountryData.CreateVATData;
        LibraryERMCountryData.CreateGeneralPostingSetupData;
        LibraryERMCountryData.UpdateGeneralPostingSetup;
        LibraryInventory.NoSeriesSetup(InventorySetup);
        isInitialized := true;
        Commit();
        LibraryTestInitialize.OnAfterTestSuiteInitialize(CODEUNIT::"SCM Inventory Item Tracking II");
    end;

    local procedure AssignSerialNoOnPurchaseOrder(var PurchaseHeader: Record "Purchase Header"; PurchaseLine: Record "Purchase Line")
    begin
        PurchaseHeader.Get(PurchaseLine."Document Type", PurchaseLine."Document No.");
        LibraryVariableStorage.Enqueue(TrackingOption::AssignSerialNo);  // Enqueue value for ItemTrackingLinesPageHandler.
        PurchaseLine.OpenItemTrackingLines;
    end;

    local procedure AssignSerialNoAndReceivePurchaseOrder(var PurchaseHeader: Record "Purchase Header"; PurchaseLine: Record "Purchase Line")
    begin
        AssignSerialNoOnPurchaseOrder(PurchaseHeader, PurchaseLine);
        LibraryPurchase.PostPurchaseDocument(PurchaseHeader, true, false);  // Post Purchase Receipt.
        UpdatePurchaseLine(PurchaseLine);  // Update Quatity-to Invoice with partial Quantity.
    end;

    local procedure AssignTrackingAndReserveOnSalesLine(SalesLine: Record "Sales Line"; SummaryOption: Option; Quantity: Decimal)
    begin
        SalesLine.OpenItemTrackingLines;
        LibraryVariableStorage.Enqueue(SerialLotConfirmMessage);  // Enqueue value for ConfirmHandler.
        SalesLine.ShowReservation;
        LibraryVariableStorage.Enqueue(TrackingOption::SelectEntries);  // Enqueue value for ItemTrackingLinesPageHandler.
        LibraryVariableStorage.Enqueue(SummaryOption);  // Enqueue value for ItemTrackingSummaryPageHandler.
        LibraryVariableStorage.Enqueue(Quantity);
        SalesLine.OpenItemTrackingLines;
    end;

    local procedure CalcRegenPlanAndCarryOutActionMsg(Item: Record Item; LocationCode: Code[10]; VendorNo: Code[20])
    var
        RequisitionLine: Record "Requisition Line";
    begin
        LibraryPlanning.CalcRegenPlanForPlanWksh(Item, WorkDate, CalcDate('<CY>', WorkDate));  // Dates based on WORKDATE.
        FindAndUpdateRequisitionLine(RequisitionLine, Item."No.", LocationCode, VendorNo);
        LibraryPlanning.CarryOutActionMsgPlanWksh(RequisitionLine);
    end;

    local procedure CreateLotSNWarehouseTrackingItem(): Code[20]
    var
        Item: Record Item;
    begin
        LibraryInventory.CreateTrackedItem(Item, '', '', CreateLotSNWarehouseItemTrackingCode);
        exit(Item."No.");
    end;

    local procedure CreateAndUpdateItem(SerialSpecific: Boolean; LotSpecific: Boolean): Code[20]
    var
        Item: Record Item;
        ExpirationDate: DateFormula;
    begin
        CreateTrackedItem(
          Item, LibraryUtility.GetGlobalNoSeriesCode, LibraryUtility.GetGlobalNoSeriesCode,
          CreateItemTrackingCode(LotSpecific, SerialSpecific, true));
        Evaluate(ExpirationDate, '<' + Format(LibraryRandom.RandInt(5)) + 'D>');
        Item.Validate("Expiration Calculation", ExpirationDate);
        Item.Modify(true);
        exit(Item."No.");
    end;

    local procedure CreateAndPostItemJournalLineWithIT(var ItemJournalLine: Record "Item Journal Line")
    var
        Item: Record Item;
        Bin: Record Bin;
        LotNo: Variant;
    begin
        CreateTrackedItem(Item, LibraryUtility.GetGlobalNoSeriesCode, '', CreateItemTrackingCode(true, false, false));
        CreateLocationWithBin(Bin);
        CreateItemJournalLine(ItemJournalLine, Item."No.", Bin."Location Code", Bin.Code, LibraryRandom.RandInt(10));  // Take random Quantity.
        LibraryVariableStorage.Enqueue(TrackingOption::AssignLotNo);  // Enqueue value for ItemTrackingLinesPageHandler.
        ItemJournalLine.OpenItemTrackingLines(false);
        LibraryInventory.PostItemJournalLine(ItemJournalLine."Journal Template Name", ItemJournalLine."Journal Batch Name");
        LibraryVariableStorage.Dequeue(LotNo);
    end;

    local procedure CreateAndPostPosAdjmtItemJournalLineWithIT(Bin: Record Bin; ItemNo: Code[20]; Quantity: Decimal)
    var
        ItemJournalLine: Record "Item Journal Line";
    begin
        CreateItemJournalLine(ItemJournalLine, ItemNo, Bin."Location Code", Bin.Code, Quantity);
        LibraryVariableStorage.Enqueue(TrackingOption::SetLotAndSerial);  // Enqueue value for ItemTrackingLinesPageHandler.
        LibraryVariableStorage.Enqueue(LibraryUtility.GenerateGUID);
        LibraryVariableStorage.Enqueue(LibraryUtility.GenerateGUID);
        LibraryVariableStorage.Enqueue(Quantity);
        ItemJournalLine.OpenItemTrackingLines(false);
        LibraryInventory.PostItemJournalLine(ItemJournalLine."Journal Template Name", ItemJournalLine."Journal Batch Name");
    end;

    local procedure CreateItemWarehouseInventoryWithLotInfo(var ItemJournalLine: Record "Item Journal Line"; ItemNo: Code[20]) LotNo: Code[20]
    begin
        LotNo := CreateLotNoInformation(ItemNo);
        CreateItemWarehouseInventoryWithTrackingAttribute(ItemJournalLine, ItemNo, TrackingOption::EditValue, LotNo);
    end;

    local procedure CreateItemWarehouseInventoryWithSNInfo(var ItemJournalLine: Record "Item Journal Line"; ItemNo: Code[20]) SN: Code[20]
    begin
        SN := CreateSNInformation(ItemNo);
        CreateItemWarehouseInventoryWithTrackingAttribute(ItemJournalLine, ItemNo, TrackingOption::EditSNValue, SN);
    end;

    local procedure CreateItemWarehouseInventoryWithTrackingAttribute(var ItemJournalLine: Record "Item Journal Line"; ItemNo: Code[20]; TrackingOptionPar: Option; AttributeValue: Code[20])
    var
        Location: Record Location;
    begin
        LibraryWarehouse.CreateLocationWithInventoryPostingSetup(Location);
        CreateItemJournalLine(ItemJournalLine, ItemNo, Location.Code, '', LibraryRandom.RandInt(10));  // Take random Quantity.
        SetItemJournalLineTrackingAttribute(ItemJournalLine, TrackingOptionPar, AttributeValue);
        LibraryInventory.PostItemJournalLine(ItemJournalLine."Journal Template Name", ItemJournalLine."Journal Batch Name");
    end;

    local procedure CreateAndPostPurchaseOrderWithIT(var PurchaseLine: Record "Purchase Line"; ItemNo: Code[20]; TrackOption: Option)
    begin
        CreatePurchaseOrder(PurchaseLine, ItemNo, LibraryRandom.RandInt(10) + 20);  // Quantity shoulb be always more thant 20 required for Test.
        LibraryVariableStorage.Enqueue(TrackOption);  // Enqueue value for ItemTrackingLinesPageHandler.
        PurchaseLine.OpenItemTrackingLines;
        PostPurchaseOrder(PurchaseLine);
    end;

    local procedure CreateAndRefreshProductionOrderOnLocation(var ProductionOrder: Record "Production Order"; LocationCode: Code[10]; ItemNo: Code[20]; Qty: Decimal)
    begin
        LibraryManufacturing.CreateProductionOrder(
          ProductionOrder, ProductionOrder.Status::Released, ProductionOrder."Source Type"::Item, ItemNo, Qty);
        ProductionOrder.Validate("Location Code", LocationCode);
        ProductionOrder.Modify(true);
        LibraryManufacturing.RefreshProdOrder(ProductionOrder, false, true, true, true, true);
    end;

    local procedure CreateCustomer(): Code[20]
    var
        Customer: Record Customer;
    begin
        LibrarySales.CreateCustomer(Customer);
        exit(Customer."No.");
    end;

    local procedure CreateSalesCreditMemo(var SalesHeader: Record "Sales Header"; No: Code[20]; SellToCustomerNo: Code[20])
    var
        ReturnReceiptLine: Record "Return Receipt Line";
        SalesGetReturnReceipts: Codeunit "Sales-Get Return Receipts";
    begin
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::"Credit Memo", SellToCustomerNo);
        SalesGetReturnReceipts.SetSalesHeader(SalesHeader);
        ReturnReceiptLine.SetRange("Sell-to Customer No.", SalesHeader."Sell-to Customer No.");
        ReturnReceiptLine.SetRange("No.", No);
        ReturnReceiptLine.FindFirst;
        SalesGetReturnReceipts.CreateInvLines(ReturnReceiptLine);
    end;

    local procedure CreateInventoryPickOnSalesLine(var SalesLine: Record "Sales Line"): Code[20]
    var
        SalesHeader: Record "Sales Header";
        WarehouseActivityLine: Record "Warehouse Activity Line";
        WarehouseActivityHeader: Record "Warehouse Activity Header";
    begin
        SalesHeader.Get(SalesLine."Document Type", SalesLine."Document No.");
        LibrarySales.ReleaseSalesDocument(SalesHeader);
        LibraryVariableStorage.Enqueue(PickCreated);
        LibraryWarehouse.CreateInvtPutPickMovement(SalesHeader."Document Type", SalesHeader."No.", false, true, false);
        FindWarehouseActivityLine(
          WarehouseActivityLine, SalesHeader."No.", WarehouseActivityLine."Activity Type"::"Invt. Pick", SalesLine."Location Code",
          WarehouseActivityLine."Action Type"::Take);
        WarehouseActivityHeader.SetRange("No.", WarehouseActivityLine."No.");
        WarehouseActivityLine.Validate("Qty. to Handle", WarehouseActivityLine.Quantity);
        WarehouseActivityLine.Modify(true);
        WarehouseActivityHeader.FindFirst;
        exit(WarehouseActivityHeader."No.");
    end;

    local procedure CreateInvtPutAwayForProdOrder(var WhseActivHeader: Record "Warehouse Activity Header"; ProdOrderLine: Record "Prod. Order Line"; QtyToHandle: Decimal)
    var
        Bin: Record Bin;
        WhseActivLine: Record "Warehouse Activity Line";
    begin
        LibraryWarehouse.FindBin(Bin, ProdOrderLine."Location Code", '', 1);

        LibraryWarehouse.CreateInvtPutPickMovement(
          WhseActivLine."Source Document"::"Prod. Output", ProdOrderLine."Prod. Order No.", true, false, false);
        LibraryWarehouse.FindWhseActivityBySourceDoc(
          WhseActivHeader, DATABASE::"Prod. Order Line", ProdOrderLine.Status, ProdOrderLine."Prod. Order No.", ProdOrderLine."Line No.");
        WhseActivLine.SetRange("No.", WhseActivHeader."No.");
        WhseActivLine.FindFirst;
        WhseActivLine.Validate("Bin Code", Bin.Code);
        WhseActivLine.Validate("Lot No.", LibraryUtility.GenerateGUID);
        WhseActivLine.Validate("Qty. to Handle", QtyToHandle);
        WhseActivLine.Modify(true);
    end;

    local procedure CreateItemReclassificationJournal(var ItemJournalLine: Record "Item Journal Line"; ItemNo: Code[20]; LocationCode: Code[10]; BinCode: Code[20]; Quantity: Decimal)
    var
        ItemJournalBatch: Record "Item Journal Batch";
        SummaryOption: Option SetQuantity,VerifyQuantity;
    begin
        SelectAndClearItemJournalBatch(ItemJournalBatch, ItemJournalBatch."Template Type"::Transfer);
        LibraryInventory.CreateItemJournalLine(
          ItemJournalLine, ItemJournalBatch."Journal Template Name", ItemJournalBatch.Name, ItemJournalLine."Entry Type"::Transfer, ItemNo,
          Quantity);
        ItemJournalLine.Validate("Location Code", LocationCode);
        ItemJournalLine.Validate("Bin Code", BinCode);
        ItemJournalLine.Modify(true);
        LibraryVariableStorage.Enqueue(TrackingOption::SelectEntries);  // Enqueue value for ItemTrackingLinesPageHandler.
        LibraryVariableStorage.Enqueue(SummaryOption::SetQuantity);
        LibraryVariableStorage.Enqueue(ItemJournalLine.Quantity);
        ItemJournalLine.OpenItemTrackingLines(true);
    end;

    local procedure CreateItemReclassificationJournalLine(var ItemJournalLine: Record "Item Journal Line"; ItemNo: Code[20]; LocationCode: Code[10]; Quantity: Decimal)
    var
        ItemJournalBatch: Record "Item Journal Batch";
    begin
        SelectAndClearItemJournalBatch(ItemJournalBatch, ItemJournalBatch."Template Type"::Transfer);
        LibraryInventory.CreateItemJournalLine(
          ItemJournalLine, ItemJournalBatch."Journal Template Name", ItemJournalBatch.Name, ItemJournalLine."Entry Type"::Transfer,
          ItemNo, Quantity);
        ItemJournalLine.Validate("Location Code", LocationCode);
        ItemJournalLine.Modify(true);
    end;

    local procedure CreateItemReclassificationJournalLineWithTrackingAttribute(var ItemJournalLine: Record "Item Journal Line"; ItemNo: Code[20]; LocationCode: Code[10]; Quantity: Decimal; TrackingOptionPar: Option; OldAttributeValue: Code[20]; NewAttributeValue: Code[20])
    begin
        CreateItemReclassificationJournalLine(ItemJournalLine, ItemNo, LocationCode, Quantity);
        SetItemJournalLineNewTrackingAttribute(ItemJournalLine, TrackingOptionPar, OldAttributeValue, NewAttributeValue);
    end;

    local procedure SetItemJournalLineNewTrackingAttribute(var ItemJournalLine: Record "Item Journal Line"; TrackingOptionPar: Option; OldAttributeValue: Code[20]; NewAttributeValue: Code[20])
    begin
        LibraryVariableStorage.Enqueue(TrackingOptionPar);  // Enqueue value for ItemTrackingLinesPageHandler.
        LibraryVariableStorage.Enqueue(OldAttributeValue);
        LibraryVariableStorage.Enqueue(NewAttributeValue);
        ItemJournalLine.OpenItemTrackingLines(true);
    end;

    local procedure SetItemJournalLineTrackingAttribute(var ItemJournalLine: Record "Item Journal Line"; TrackingOptionPar: Option; AttributeValue: Code[20])
    begin
        LibraryVariableStorage.Enqueue(TrackingOptionPar);  // Enqueue value for ItemTrackingLinesPageHandler.
        LibraryVariableStorage.Enqueue(AttributeValue);
        ItemJournalLine.OpenItemTrackingLines(true);
    end;

    local procedure CreateTrackedItem(var Item: Record Item; LotNos: Code[20]; SerialNos: Code[20]; ItemTrackingCode: Code[10])
    begin
        LibraryInventory.CreateTrackedItem(Item, LotNos, SerialNos, ItemTrackingCode);
        Item.Validate("Reordering Policy", Item."Reordering Policy"::Order);
        Item.Modify(true);
    end;

    local procedure CreateItemJournalLine(var ItemJournalLine: Record "Item Journal Line"; ItemNo: Code[20]; LocationCode: Code[10]; BinCode: Code[20]; Quantity: Decimal)
    var
        ItemJournalBatch: Record "Item Journal Batch";
    begin
        SelectAndClearItemJournalBatch(ItemJournalBatch, ItemJournalBatch."Template Type"::Item);
        LibraryInventory.CreateItemJournalLine(
          ItemJournalLine, ItemJournalBatch."Journal Template Name", ItemJournalBatch.Name,
          ItemJournalLine."Entry Type"::"Positive Adjmt.", ItemNo, Quantity);
        ItemJournalLine.Validate("Location Code", LocationCode);
        ItemJournalLine.Validate("Bin Code", BinCode);
        ItemJournalLine.Modify(true);
    end;

    local procedure CreateItemTrackingCode(LOTSpecific: Boolean; SNSpecific: Boolean; UseExpirationDate: Boolean): Code[10]
    var
        ItemTrackingCode: Record "Item Tracking Code";
    begin
        if UseExpirationDate then
            LibraryItemTracking.CreateItemTrackingCodeWithExpirationDate(ItemTrackingCode, SNSpecific, LOTSpecific)
        else
            LibraryItemTracking.CreateItemTrackingCode(ItemTrackingCode, SNSpecific, LOTSpecific);
        exit(ItemTrackingCode.Code);
    end;

    local procedure CreateLotSNWarehouseItemTrackingCode(): Code[10]
    var
        ItemTrackingCode: Record "Item Tracking Code";
    begin
        LibraryItemTracking.CreateItemTrackingCode(ItemTrackingCode, true, true);
        ItemTrackingCode.Validate("SN Warehouse Tracking", true);
        ItemTrackingCode.Validate("Lot Warehouse Tracking", true);
        ItemTrackingCode.Modify(true);
        exit(ItemTrackingCode.Code);
    end;

    local procedure CreateItemInboundLotInfoMustExist(var Item: Record Item)
    begin
        CreateTrackedItem(
          Item, '', LibraryUtility.GetGlobalNoSeriesCode, CreateItemTrackingCodeInboundInfoMustExist(true, false, true, false));
    end;

    local procedure CreateItemInboundSNInfoMustExist(var Item: Record Item)
    begin
        CreateTrackedItem(
          Item, '', LibraryUtility.GetGlobalNoSeriesCode, CreateItemTrackingCodeInboundInfoMustExist(false, true, false, true));
    end;

    local procedure CreateItemTrackingCodeInboundInfoMustExist(LotSpecific: Boolean; SNSpecific: Boolean; InboundLotNoInfoMustExist: Boolean; InboundSNInfoMustExist: Boolean): Code[10]
    var
        ItemTrackingCode: Record "Item Tracking Code";
    begin
        LibraryInventory.CreateItemTrackingCode(ItemTrackingCode);
        with ItemTrackingCode do begin
            Validate("Lot Specific Tracking", LotSpecific);
            Validate("SN Specific Tracking", SNSpecific);
            Validate("Lot Info. Inbound Must Exist", InboundLotNoInfoMustExist);
            Validate("SN Info. Inbound Must Exist", InboundSNInfoMustExist);
            Modify(true);
            exit(Code);
        end;
    end;

    local procedure CreateLotNoInformation(ItemNo: Code[20]): Code[20]
    var
        LotNoInformation: Record "Lot No. Information";
    begin
        LibraryInventory.CreateLotNoInformation(
          LotNoInformation, ItemNo, '',
          LibraryUtility.GenerateRandomCode(LotNoInformation.FieldNo("Lot No."), DATABASE::"Lot No. Information"));
        exit(LotNoInformation."Lot No.");
    end;

    local procedure CreateSNInformation(ItemNo: Code[20]): Code[20]
    var
        SerialNoInformation: Record "Serial No. Information";
    begin
        LibraryInventory.CreateSerialNoInformation(
          SerialNoInformation, ItemNo, '',
          LibraryUtility.GenerateRandomCode(SerialNoInformation.FieldNo("Serial No."), DATABASE::"Serial No. Information"));
        exit(SerialNoInformation."Serial No.");
    end;

    local procedure CreateLocationWithBin(var Bin: Record Bin)
    var
        Location: Record Location;
        WarehouseEmployee: Record "Warehouse Employee";
    begin
        LibraryWarehouse.CreateLocationWithInventoryPostingSetup(Location);
        Location.Validate("Bin Mandatory", true);
        Location.Validate("Require Pick", true);
        Location.Modify(true);
        LibraryWarehouse.CreateWarehouseEmployee(WarehouseEmployee, Location.Code, false);
        LibraryWarehouse.CreateBin(
          Bin, Location.Code,
          CopyStr(
            LibraryUtility.GenerateRandomCode(Bin.FieldNo(Code), DATABASE::Bin), 1,
            LibraryUtility.GetFieldLength(DATABASE::Bin, Bin.FieldNo(Code))), '', '');
    end;

    local procedure CreateLocationWithReceiveShipRequired(): Code[10]
    var
        Location: Record Location;
        Bin: Record Bin;
        WarehouseEmployee: Record "Warehouse Employee";
    begin
        LibraryWarehouse.CreateLocationWithInventoryPostingSetup(Location);
        with Location do begin
            Validate("Bin Mandatory", true);
            Validate("Require Receive", true);
            Validate("Require Shipment", true);
            LibraryWarehouse.CreateWarehouseEmployee(WarehouseEmployee, Code, false);
            LibraryWarehouse.CreateBin(
              Bin, Code, CopyStr(
                LibraryUtility.GenerateRandomCode(Bin.FieldNo(Code), DATABASE::Bin), 1,
                LibraryUtility.GetFieldLength(DATABASE::Bin, Bin.FieldNo(Code))), '', '');
            Validate("Receipt Bin Code", Bin.Code);
            LibraryWarehouse.CreateBin(
              Bin, Code, CopyStr(
                LibraryUtility.GenerateRandomCode(Bin.FieldNo(Code), DATABASE::Bin), 1,
                LibraryUtility.GetFieldLength(DATABASE::Bin, Bin.FieldNo(Code))), '', '');
            Validate("Shipment Bin Code", Bin.Code);
            Modify(true);
            exit(Code);
        end;
    end;

    local procedure CreatePutawayPickLocation(): Code[10]
    var
        Location: Record Location;
    begin
        LibraryWarehouse.CreateLocationWMS(Location, true, true, true, false, false);
        LibraryWarehouse.CreateNumberOfBins(Location.Code, '', '', 1, false);
        exit(Location.Code);
    end;

    local procedure CreateWhseLotSpecificTrackedItem(var Item: Record Item; SNTracking: Boolean)
    var
        ItemTrackingCode: Record "Item Tracking Code";
    begin
        with ItemTrackingCode do begin
            Get(CreateItemTrackingCode(true, false, true));
            Validate("Lot Warehouse Tracking", true);
            Validate("SN Purchase Inbound Tracking", SNTracking);
            Modify(true);
            CreateTrackedItem(Item, LibraryUtility.GetGlobalNoSeriesCode, LibraryUtility.GetGlobalNoSeriesCode, Code);
        end;
        Evaluate(Item."Expiration Calculation", '<1Y>');
        Item.Modify(true);
    end;

    local procedure CreatePurchaseOrderWithLocation(var PurchaseLine: Record "Purchase Line"; LocationCode: Code[10]; BinCode: Code[20])
    begin
        CreatePurchaseOrder(PurchaseLine, CreateAndUpdateItem(true, false), 2 * LibraryRandom.RandInt(10));  // Take random Quantity.
        PurchaseLine.Validate("Location Code", LocationCode);
        PurchaseLine.Validate("Bin Code", BinCode);
        PurchaseLine.Modify(true);
    end;

    local procedure CreatePurchaseOrderWithIT(var PurchaseLine: Record "Purchase Line"; ItemNo: Code[20]; LotNo: Code[20])
    begin
        CreatePurchaseOrder(PurchaseLine, ItemNo, PurchaseLine.Quantity);  // Take random Quantity.
        LibraryVariableStorage.Enqueue(TrackingOption::EditValue);  // Enqueue value for ItemTrackingLinesPageHandler.
        LibraryVariableStorage.Enqueue(LotNo);
        PurchaseLine.OpenItemTrackingLines;
    end;

    local procedure CreateSalesRetOrdWithIT(var SalesLine: Record "Sales Line")
    var
        Item: Record Item;
        Location: Record Location;
    begin
        CreateTrackedItem(Item, '', LibraryUtility.GetGlobalNoSeriesCode, CreateItemTrackingCode(false, true, false));  // Blank value for Lot No.
        CreateSalesDocument(
          SalesLine, SalesLine."Document Type"::"Return Order", Item."No.",
          LibraryWarehouse.CreateLocationWithInventoryPostingSetup(Location),
          LibraryRandom.RandInt(10));  // Random value for Quantity.
        LibraryVariableStorage.Enqueue(TrackingOption::AssignSerialNo);  // Enqueue value for ItemTrackingLinesPageHandler.
    end;

    local procedure CreateWhseShptAndRegisterPick(PurchaseLine: Record "Purchase Line")
    var
        SalesLine: Record "Sales Line";
        WarehouseActivityHeader: Record "Warehouse Activity Header";
        WarehouseShipmentHeader: Record "Warehouse Shipment Header";
    begin
        CreateSalesOrderWithIT(SalesLine, PurchaseLine."No.", PurchaseLine."Location Code", PurchaseLine.Quantity / 2, 1);  // Taking 1 for Quantity as Item Tracking code is Serial Specific.
        CreateWarehouseShipment(SalesLine."Document No.");
        WarehouseShipmentHeader.SetRange("Location Code", PurchaseLine."Location Code");
        WarehouseShipmentHeader.FindFirst;
        LibraryWarehouse.CreatePick(WarehouseShipmentHeader);
        RegisterWarehouseActivity(SalesLine."Document No.", WarehouseActivityHeader.Type::Pick, PurchaseLine."Location Code");
    end;

    local procedure CreateSetupforSalesOrder(var SalesLine: Record "Sales Line"; LOTSpecific: Boolean; SNSpecific: Boolean)
    var
        Location: Record Location;
        Item: Record Item;
    begin
        CreateTrackedItem(
          Item, LibraryUtility.GetGlobalNoSeriesCode, LibraryUtility.GetGlobalNoSeriesCode,
          CreateItemTrackingCode(LOTSpecific, SNSpecific, false));
        LibraryWarehouse.CreateLocation(Location);
        CreateSalesDocument(SalesLine, SalesLine."Document Type"::Order, Item."No.", Location.Code, LibraryRandom.RandInt(10));  // Take random for Quantity.
    end;

    local procedure CreateSalesDocument(var SalesLine: Record "Sales Line"; DocumentType: Option; No: Code[20]; LocationCode: Code[10]; Quantity: Decimal)
    var
        SalesHeader: Record "Sales Header";
    begin
        LibrarySales.CreateSalesHeader(SalesHeader, DocumentType, CreateCustomer);
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, No, Quantity);
        SalesLine.Validate("Location Code", LocationCode);
        SalesLine.Modify(true);
    end;

    local procedure CreateSalesOrderWithIT(var SalesLine: Record "Sales Line"; No: Code[20]; LocationCode: Code[10]; Quantity: Decimal; SetQuantity: Decimal)
    var
        SummaryOption: Option SetQuantity,VerifyQuantity,VerifyExpirationDate;
    begin
        CreateSalesDocument(SalesLine, SalesLine."Document Type"::Order, No, LocationCode, Quantity);
        LibraryVariableStorage.Enqueue(TrackingOption::SelectEntries);  // Enqueue value for ItemTrackingLinesPageHandler.
        LibraryVariableStorage.Enqueue(SummaryOption::SetQuantity);  // Enqueue value for ItemTrackingSummaryPageHandler.
        LibraryVariableStorage.Enqueue(SetQuantity);
        SalesLine.OpenItemTrackingLines;
    end;

    local procedure CreatePurchaseOrder(var PurchaseLine: Record "Purchase Line"; ItemNo: Code[20]; Quantity: Decimal)
    var
        GLAccount: Record "G/L Account";
        PurchaseHeader: Record "Purchase Header";
    begin
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, '');
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, ItemNo, Quantity);
        LibraryERM.FindGLAccount(GLAccount);
        UpdateGeneralLedgerSetup(PurchaseLine."Gen. Bus. Posting Group", PurchaseLine."Gen. Prod. Posting Group", GLAccount."No.");
    end;

    local procedure CreatePurchOrderWithLocation(var PurchaseLine: Record "Purchase Line"; LocationCode: Code[10]; ItemNo: Code[20]; Quantity: Decimal)
    var
        PurchaseHeader: Record "Purchase Header";
    begin
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, '');
        PurchaseHeader.Validate("Location Code", LocationCode);
        PurchaseHeader.Modify(true);
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, ItemNo, Quantity);
    end;

    local procedure CreateWarehouseShipment(DocumentNo: Code[20])
    var
        SalesHeader: Record "Sales Header";
    begin
        SalesHeader.Get(SalesHeader."Document Type"::Order, DocumentNo);
        LibrarySales.ReleaseSalesDocument(SalesHeader);
        LibraryWarehouse.CreateWhseShipmentFromSO(SalesHeader);
    end;

    local procedure CreateInvtPutawayWithLotSNTrackingItemPurchase(var WarehouseActivityLine: Record "Warehouse Activity Line")
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        WarehouseRequest: Record "Warehouse Request";
    begin
        LibraryPurchase.CreatePurchaseDocumentWithItem(
          PurchaseHeader, PurchaseLine, PurchaseHeader."Document Type"::Order, '',
          CreateLotSNWarehouseTrackingItem, 1, CreatePutawayPickLocation, WorkDate);
        LibraryPurchase.ReleasePurchaseDocument(PurchaseHeader);
        LibraryWarehouse.CreateInvtPutPickMovement(
          WarehouseRequest."Source Document"::"Purchase Order", PurchaseHeader."No.", true, false, false);
        FindWarehouseActivityLine(
          WarehouseActivityLine, PurchaseHeader."No.", WarehouseActivityLine."Activity Type"::"Invt. Put-away",
          PurchaseLine."Location Code", WarehouseActivityLine."Action Type"::Place);
    end;

    local procedure CreateInvtPutawayWithLotSNTrackingItemProduction(var WarehouseActivityLine: Record "Warehouse Activity Line")
    var
        ProductionOrder: Record "Production Order";
        WarehouseRequest: Record "Warehouse Request";
    begin
        LibraryManufacturing.CreateProductionOrder(
          ProductionOrder, ProductionOrder.Status::Released, ProductionOrder."Source Type"::Item, CreateLotSNWarehouseTrackingItem, 1);
        ProductionOrder.Validate("Location Code", CreatePutawayPickLocation);
        ProductionOrder.Modify(true);
        LibraryManufacturing.RefreshProdOrder(ProductionOrder, false, true, true, true, true);
        LibraryWarehouse.CreateInvtPutPickMovement(
          WarehouseRequest."Source Document"::"Prod. Output", ProductionOrder."No.", true, false, false);
        FindWarehouseActivityLine(
          WarehouseActivityLine, ProductionOrder."No.", WarehouseActivityLine."Activity Type"::"Invt. Put-away",
          ProductionOrder."Location Code", WarehouseActivityLine."Action Type"::Place);
    end;

    local procedure CreateInvtPickWithLotSNTrackingItem(var WarehouseActivityLine: Record "Warehouse Activity Line")
    var
        Bin: Record Bin;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        WarehouseRequest: Record "Warehouse Request";
        LocationCode: Code[10];
        ItemNo: Code[20];
    begin
        LocationCode := CreatePutawayPickLocation;
        ItemNo := CreateLotSNWarehouseTrackingItem;
        Bin.SetRange("Location Code", LocationCode);
        Bin.FindFirst;
        CreateAndPostPosAdjmtItemJournalLineWithIT(Bin, ItemNo, 1);
        LibrarySales.CreateSalesDocumentWithItem(
          SalesHeader, SalesLine, SalesHeader."Document Type"::Order, '',
          ItemNo, 1, LocationCode, WorkDate);
        LibrarySales.ReleaseSalesDocument(SalesHeader);
        LibraryWarehouse.CreateInvtPutPickMovement(
          WarehouseRequest."Source Document"::"Sales Order", SalesHeader."No.", false, true, false);
        FindWarehouseActivityLine(
          WarehouseActivityLine, SalesHeader."No.", WarehouseActivityLine."Activity Type"::"Invt. Pick", SalesLine."Location Code",
          WarehouseActivityLine."Action Type"::Take);
    end;

    local procedure DeleteItemTrackingLines(SalesLine: Record "Sales Line")
    var
        RequisitionLine: Record "Requisition Line";
    begin
        FindRequisitionLine(RequisitionLine, SalesLine."No.", SalesLine."Location Code");
        LibraryVariableStorage.Enqueue(TrackingOption::EditValue); // Enqueue value for ItemTrackingLinesPageHandler.
        LibraryVariableStorage.Enqueue(''); // Enqueue value for ItemTrackingLinesPageHandler.
        RequisitionLine.OpenItemTrackingLines;
    end;

    local procedure EnqueueQuantityForReselectEntries(TrackingOptionPar: Option; SummaryOption: Option; SummaryOption2: Option; TotalAvailableQuantity: Decimal; TotalRequestedQuantity: Decimal; CurrentPendingQuantity: Decimal)
    begin
        // Enqueue value for ItemTrackingLinesPageHandler.
        LibraryVariableStorage.Enqueue(TrackingOptionPar);
        LibraryVariableStorage.Enqueue(SummaryOption);
        LibraryVariableStorage.Enqueue(SummaryOption2);
        LibraryVariableStorage.Enqueue(TotalAvailableQuantity);
        LibraryVariableStorage.Enqueue(TotalRequestedQuantity);
        LibraryVariableStorage.Enqueue(CurrentPendingQuantity);
    end;

    local procedure FindItemLedgerEntry(var ItemLedgerEntry: Record "Item Ledger Entry"; ItemNo: Code[20])
    begin
        ItemLedgerEntry.SetRange("Item No.", ItemNo);
        ItemLedgerEntry.FindFirst;
    end;

    local procedure FindAndUpdateRequisitionLine(var RequisitionLine: Record "Requisition Line"; No: Code[20]; LocationCode: Code[10]; VendorNo: Code[20])
    begin
        FindRequisitionLine(RequisitionLine, No, LocationCode);
        RequisitionLine.Validate("Accept Action Message", true);
        RequisitionLine.Validate("Vendor No.", VendorNo);
        RequisitionLine.Modify(true);
    end;

    local procedure FindProdOrderLine(var ProdOrderLine: Record "Prod. Order Line"; ProductionOrder: Record "Production Order")
    begin
        ProdOrderLine.SetRange(Status, ProductionOrder.Status);
        ProdOrderLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        ProdOrderLine.FindFirst;
    end;

    local procedure FindReservationEntry(var ReservationEntry: Record "Reservation Entry"; LocationCode: Code[10]; ItemNo: Code[20])
    begin
        ReservationEntry.SetRange("Location Code", LocationCode);
        ReservationEntry.SetRange("Item No.", ItemNo);
        ReservationEntry.FindFirst;
    end;

    local procedure FindReservationEntryForSerialNo(ItemNo: Code[20]; LocationCode: Code[10]; SerialNo: Code[50])
    var
        ReservationEntry: Record "Reservation Entry";
    begin
        FindReservationEntry(ReservationEntry, LocationCode, ItemNo);
        ReservationEntry.SetRange("Serial No.", SerialNo);
        ReservationEntry.FindFirst;
    end;

    local procedure FindRequisitionLine(var RequisitionLine: Record "Requisition Line"; No: Code[20]; LocationCode: Code[10])
    begin
        RequisitionLine.SetRange(Type, RequisitionLine.Type::Item);
        RequisitionLine.SetRange("No.", No);
        RequisitionLine.SetRange("Location Code", LocationCode);
        RequisitionLine.FindFirst;
    end;

    local procedure FindSalesLine(var SalesLine: Record "Sales Line"; DocumentType: Option; DocumentNo: Code[20])
    begin
        SalesLine.SetRange("Document Type", DocumentType);
        SalesLine.SetRange("Document No.", DocumentNo);
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        SalesLine.FindFirst;
    end;

    local procedure FindWarehouseActivityLine(var WarehouseActivityLine: Record "Warehouse Activity Line"; SourceNo: Code[20]; ActivityType: Option; LocationCode: Code[10]; ActionType: Option)
    begin
        WarehouseActivityLine.SetRange("Source No.", SourceNo);
        WarehouseActivityLine.SetRange("Location Code", LocationCode);
        WarehouseActivityLine.SetRange("Activity Type", ActivityType);
        WarehouseActivityLine.SetRange("Action Type", ActionType);
        WarehouseActivityLine.FindFirst;
    end;

    local procedure FindWarehouseReceiptNo(SourceDocument: Option; SourceNo: Code[20]): Code[20]
    var
        WarehouseReceiptLine: Record "Warehouse Receipt Line";
    begin
        WarehouseReceiptLine.SetRange("Source Document", SourceDocument);
        WarehouseReceiptLine.SetRange("Source No.", SourceNo);
        WarehouseReceiptLine.FindFirst;
        exit(WarehouseReceiptLine."No.");
    end;

    local procedure SetupSalesAndPurchEntryWithIT(var SalesLine: Record "Sales Line"; Quantity: Integer)
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        SummaryOption: Option SetQuantity,VerifyQuantity,VerifyExpirationDate;
    begin
        // Create Item, update Expiration calculation on Item, create and post Purchase Order, create Sales Order.
        CreatePurchaseOrder(PurchaseLine, CreateAndUpdateItem(true, false), Quantity);
        AssignSerialNoAndReceivePurchaseOrder(PurchaseHeader, PurchaseLine);
        CreateSalesDocument(SalesLine, SalesLine."Document Type"::Order, PurchaseLine."No.", '', Quantity);
        LibraryVariableStorage.Enqueue(TrackingOption::SelectEntries);  // Enqueue value for ItemTrackingLinesPageHandler.
        LibraryVariableStorage.Enqueue(SummaryOption::SetQuantity);  // Enqueue value for ItemTrackingSummaryPageHandler.
    end;

    local procedure PostPurchaseOrderWithLocation(var PurchaseLine: Record "Purchase Line")
    var
        Bin: Record Bin;
        PurchaseHeader: Record "Purchase Header";
    begin
        CreateLocationWithBin(Bin);
        CreatePurchaseOrderWithLocation(PurchaseLine, Bin."Location Code", Bin.Code);
        AssignSerialNoAndReceivePurchaseOrder(PurchaseHeader, PurchaseLine);
    end;

    local procedure PostPurchaseOrder(PurchaseLine: Record "Purchase Line")
    var
        PurchaseHeader: Record "Purchase Header";
    begin
        PurchaseHeader.Get(PurchaseLine."Document Type", PurchaseLine."Document No.");
        LibraryPurchase.PostPurchaseDocument(PurchaseHeader, true, true);
    end;

    local procedure PostSalesDocument(DocumentType: Option; DocumentNo: Code[20]; Invoice: Boolean): Code[20]
    var
        SalesHeader: Record "Sales Header";
    begin
        SalesHeader.Get(DocumentType, DocumentNo);
        exit(LibrarySales.PostSalesDocument(SalesHeader, true, Invoice));
    end;

    local procedure PostWhseRcptAndRegisterPutAway(var PurchaseLine: Record "Purchase Line")
    var
        Location: Record Location;
        WarehouseEmployee: Record "Warehouse Employee";
        PurchaseHeader: Record "Purchase Header";
        WarehouseReceiptLine: Record "Warehouse Receipt Line";
        WarehouseActivityHeader: Record "Warehouse Activity Header";
    begin
        LibraryWarehouse.CreateFullWMSLocation(Location, 1);
        LibraryWarehouse.CreateWarehouseEmployee(WarehouseEmployee, Location.Code, false);

        // Create Purchase Order with Item Tracking.
        CreatePurchaseOrderWithLocation(PurchaseLine, Location.Code, '');
        AssignSerialNoOnPurchaseOrder(PurchaseHeader, PurchaseLine);
        PurchaseHeader.Get(PurchaseLine."Document Type", PurchaseLine."Document No.");
        LibraryPurchase.ReleasePurchaseDocument(PurchaseHeader);

        // Create Warehouse Receipt from Purchase Order and Register.
        LibraryWarehouse.CreateWhseReceiptFromPO(PurchaseHeader);
        PostWarehouseReceipt(WarehouseReceiptLine."Source Document"::"Purchase Order", PurchaseHeader."No.");
        RegisterWarehouseActivity(PurchaseLine."Document No.", WarehouseActivityHeader.Type::"Put-away", PurchaseLine."Location Code");
    end;

    local procedure PostWarehouseReceipt(SourceDocument: Option; SourceNo: Code[20])
    var
        WarehouseReceiptHeader: Record "Warehouse Receipt Header";
    begin
        WarehouseReceiptHeader.Get(FindWarehouseReceiptNo(SourceDocument, SourceNo));
        LibraryWarehouse.PostWhseReceipt(WarehouseReceiptHeader);
    end;

    local procedure PostItemJournalWithTracking(ItemNo: Code[20]; TrackingNo: Code[20])
    var
        ItemJournalLine: Record "Item Journal Line";
    begin
        CreateItemJournalLine(ItemJournalLine, ItemNo, '', '', LibraryRandom.RandInt(10));
        LibraryVariableStorage.Enqueue(TrackingNo);
        ItemJournalLine.OpenItemTrackingLines(false);
        LibraryInventory.PostItemJournalLine(ItemJournalLine."Journal Template Name", ItemJournalLine."Journal Batch Name");
    end;

    local procedure RegisterWarehouseActivity(SourceNo: Code[20]; ActivityType: Option; LocationCode: Code[10])
    var
        WarehouseActivityHeader: Record "Warehouse Activity Header";
        WarehouseActivityLine: Record "Warehouse Activity Line";
    begin
        FindWarehouseActivityLine(WarehouseActivityLine, SourceNo, ActivityType, LocationCode, WarehouseActivityLine."Action Type"::Place);
        WarehouseActivityHeader.SetRange("No.", WarehouseActivityLine."No.");
        WarehouseActivityHeader.FindFirst;
        LibraryWarehouse.RegisterWhseActivity(WarehouseActivityHeader);
    end;

    local procedure SelectAndClearItemJournalBatch(var ItemJournalBatch: Record "Item Journal Batch"; TemplateType: Option)
    var
        ItemJournalTemplate: Record "Item Journal Template";
    begin
        LibraryInventory.SelectItemJournalTemplateName(ItemJournalTemplate, TemplateType);
        LibraryInventory.SelectItemJournalBatchName(ItemJournalBatch, TemplateType, ItemJournalTemplate.Name);
        LibraryInventory.ClearItemJournal(ItemJournalTemplate, ItemJournalBatch);
    end;

    local procedure SetupForMultipleExpirDateOnILE(var PurchaseLine: Record "Purchase Line"): Code[20]
    var
        Item: Record Item;
        LotNo: Variant;
    begin
        // Create and post Purchase Order having same Lot No. and update Expiration Date on Item Ledger Entry.
        CreateAndPostPurchaseOrderWithIT(PurchaseLine, CreateAndUpdateItem(false, true), TrackingOption::AssignLotNo);
        LibraryVariableStorage.Dequeue(LotNo);
        Item.Get(PurchaseLine."No.");
        CreatePurchaseOrderWithIT(PurchaseLine, PurchaseLine."No.", LotNo);
        PostPurchaseOrder(PurchaseLine);
        UpdateExpirDateOnILE(PurchaseLine."No.");
        exit(LotNo);
    end;

    local procedure UpdateExpirDateOnILE(ItemNo: Code[20]): Date
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        Item: Record Item;
        ExpirationDate: Date;
    begin
        Item.Get(ItemNo);
        ExpirationDate := CalcDate(Item."Expiration Calculation", WorkDate);
        FindItemLedgerEntry(ItemLedgerEntry, ItemNo);
        ItemLedgerEntry.Validate("Expiration Date", CalcDate('<' + Format(LibraryRandom.RandInt(5)) + 'D>', ExpirationDate));
        ItemLedgerEntry.Modify(true);
        exit(ItemLedgerEntry."Expiration Date");
    end;

    local procedure UpdateLotSerialNoInWarehouseActivityLine(var WarehouseActivityLine: Record "Warehouse Activity Line"; LNo: Code[20]; SNo: Code[20])
    begin
        WarehouseActivityLine.Validate("Lot No.", LNo);
        WarehouseActivityLine.Validate("Serial No.", SNo);
        WarehouseActivityLine.Modify(true);
    end;

    local procedure UpdatePurchaseLine(var PurchaseLine: Record "Purchase Line")
    begin
        PurchaseLine.Get(PurchaseLine."Document Type", PurchaseLine."Document No.", PurchaseLine."Line No.");
        PurchaseLine.Validate("Qty. to Invoice", PurchaseLine.Quantity / 2);  // Take partial Quantity.
        PurchaseLine.Modify(true);
    end;

    local procedure UpdatePurchaseLineAndAssignIT(var PurchaseLine: Record "Purchase Line"; FieldNo: Integer; Value: Variant; TrackingOptionPar: Option; Quantity: Decimal)
    var
        RecRef: RecordRef;
        FieldRef: FieldRef;
    begin
        // Update Purchase Line based on Field and its corresponding value.
        RecRef.GetTable(PurchaseLine);
        FieldRef := RecRef.Field(FieldNo);
        FieldRef.Validate(Value);
        RecRef.SetTable(PurchaseLine);
        PurchaseLine.Modify(true);
        LibraryVariableStorage.Enqueue(TrackingOptionPar);  // Enqueue value for ItemTrackingLinesPageHandler.
        LibraryVariableStorage.Enqueue(Quantity);
        PurchaseLine.OpenItemTrackingLines;
    end;

    local procedure UpdateGeneralLedgerSetup(GenBusPostingGroup: Code[20]; GenProdPostingGroup: Code[20]; AccountNo: Code[20])
    var
        GeneralPostingSetup: Record "General Posting Setup";
    begin
        GeneralPostingSetup.Get(GenBusPostingGroup, GenProdPostingGroup);
        GeneralPostingSetup.Validate("Sales Account", AccountNo);
        GeneralPostingSetup.Validate("Purch. Account", AccountNo);
        GeneralPostingSetup.Modify(true);
    end;

    local procedure VerifyExpirationDateOnItemLedgerEntry(ItemNo: Code[20]; ExpirationDate: Date)
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        FindItemLedgerEntry(ItemLedgerEntry, ItemNo);
        ItemLedgerEntry.TestField("Expiration Date", ExpirationDate);
    end;

    local procedure VerifyExpirationDateForItemTracking(ItemNo: Code[20]; ExpirationDate: Date)
    var
        ReservationEntry: Record "Reservation Entry";
    begin
        ReservationEntry.SetRange("Item No.", ItemNo);
        ReservationEntry.FindFirst;
        ReservationEntry.TestField("Expiration Date", ExpirationDate);
    end;

    local procedure VerifyWarehouseEntry(ItemJournalLine: Record "Item Journal Line")
    var
        WarehouseEntry: Record "Warehouse Entry";
    begin
        WarehouseEntry.SetRange("Item No.", ItemJournalLine."Item No.");
        WarehouseEntry.SetRange("Entry Type", WarehouseEntry."Entry Type"::Movement);
        WarehouseEntry.FindFirst;
        WarehouseEntry.TestField("Location Code", ItemJournalLine."Location Code");
    end;

    local procedure VerifyPurchRcpt(OrderNo: Code[20])
    var
        PurchRcptHeader: Record "Purch. Rcpt. Header";
    begin
        PurchRcptHeader.SetRange("Order No.", OrderNo);
        PurchRcptHeader.FindFirst;
        PurchRcptHeader.TestField("Order No.", OrderNo);
    end;

    local procedure VerifyPurchaseOrderItemTracking(LocationCode: Code[10]; ItemNo: Code[20]; LotNo: Code[20])
    var
        ReservationEntry: Record "Reservation Entry";
    begin
        ReservationEntry.SetRange(Positive, true);
        FindReservationEntry(ReservationEntry, LocationCode, ItemNo);
        ReservationEntry.TestField("Lot No.", LotNo);
    end;

    local procedure VerifyDeletedItemTracking(SalesLine: Record "Sales Line")
    var
        ReservationEntry: Record "Reservation Entry";
    begin
        FindReservationEntry(ReservationEntry, SalesLine."Location Code", SalesLine."No.");
        ReservationEntry.TestField("Item Tracking", ReservationEntry."Item Tracking"::None);
    end;

    local procedure VerifyWarehouseEntriesSN(ItemNo: Code[20]; ExpectedSerialNo: Code[20])
    var
        WarehouseEntry: Record "Warehouse Entry";
    begin
        with WarehouseEntry do begin
            SetRange("Item No.", ItemNo);
            FindSet;
            repeat
                Assert.AreEqual(ExpectedSerialNo, "Serial No.", WrongSerialNoErr);
            until Next = 0;
        end;
    end;

    [ConfirmHandler]
    [Scope('OnPrem')]
    procedure ConfirmHandler(ConfirmMessage: Text[1024]; var Reply: Boolean)
    var
        ExpectedMessage: Variant;
    begin
        LibraryVariableStorage.Dequeue(ExpectedMessage);  // Dequeue variable.
        Assert.IsTrue(StrPos(ConfirmMessage, ExpectedMessage) > 0, ConfirmMessage);
        Reply := true;
    end;

    [ModalPageHandler]
    [Scope('OnPrem')]
    procedure EnterQuantityToCreatePageHandler(var EnterQuantityToCreate: TestPage "Enter Quantity to Create")
    begin
        EnterQuantityToCreate.OK.Invoke;
    end;

    [ModalPageHandler]
    [Scope('OnPrem')]
    procedure EnterQuantityToCreateHandlerForSetQuantity(var EnterQuantityToCreate: TestPage "Enter Quantity to Create")
    var
        Quantity: Variant;
    begin
        LibraryVariableStorage.Dequeue(Quantity);
        EnterQuantityToCreate.QtyToCreate.SetValue(Quantity);
        EnterQuantityToCreate.OK.Invoke;
    end;

    [ModalPageHandler]
    [Scope('OnPrem')]
    procedure EnterQuantityToCreateHandlerForSetQuantityAssignLot(var EnterQuantityToCreate: TestPage "Enter Quantity to Create")
    var
        Quantity: Variant;
    begin
        LibraryVariableStorage.Dequeue(Quantity);
        EnterQuantityToCreate.QtyToCreate.SetValue(Quantity);
        EnterQuantityToCreate.CreateNewLotNo.SetValue(true);
        EnterQuantityToCreate.OK.Invoke;
    end;

    [ModalPageHandler]
    [Scope('OnPrem')]
    procedure ItemTrackingLinesPageHandler(var ItemTrackingLines: TestPage "Item Tracking Lines")
    var
        LotNo: Variant;
        NewLotNo: Variant;
        SN: Variant;
        NewSN: Variant;
        "Count": Variant;
        QuantityBase: Variant;
        SummaryOption: Option SetQuantity,VerifyQuantity,VerifyExpirationDate,AssignQty,SelectEntries,ReSelectEntries;
        TrackingOptionLoc: Option;
        Count2: Integer;
        i: Integer;
        ExpectedEditability: Boolean;
    begin
        TrackingOptionLoc := LibraryVariableStorage.DequeueInteger;  // Dequeue TrackingOption.
        case TrackingOptionLoc of
            TrackingOption::AssignSerialNo:
                begin
                    ItemTrackingLines."Assign Serial No.".Invoke;
                    Assert.IsTrue(ItemTrackingLines.First, AssignSerialNoStatus);
                end;
            TrackingOption::AssignLotNo:
                begin
                    ItemTrackingLines."Assign Lot No.".Invoke;
                    LibraryVariableStorage.Enqueue(ItemTrackingLines."Lot No.".Value);
                end;
            TrackingOption::EditValue:
                begin
                    LibraryVariableStorage.Dequeue(LotNo);
                    ItemTrackingLines."Lot No.".SetValue(LotNo);
                    ItemTrackingLines."Quantity (Base)".SetValue(ItemTrackingLines.Quantity3.AsInteger);
                end;
            TrackingOption::SelectEntries:
                ItemTrackingLines."Select Entries".Invoke;
            TrackingOption::UpdateQtyToInvoice:
                begin
                    LibraryVariableStorage.Dequeue(Count);
                    Count2 := Count;
                    for i := 1 to Count2 do
                        ItemTrackingLines."Qty. to Invoice (Base)".SetValue(0);
                end;
            TrackingOption::AssignLotNo2:
                ItemTrackingLines."Assign Lot No.".Invoke;
            TrackingOption::ReSelectEntries:
                begin
                    ItemTrackingLines."Lot No.".AssistEdit;
                    ItemTrackingLines."Lot No.".AssistEdit;
                end;
            TrackingOption::AssignQty:
                begin
                    LibraryVariableStorage.Enqueue(SummaryOption::AssignQty);  // Enqueue value for ItemTrackingSummaryPageHandler.
                    ItemTrackingLines."Lot No.".AssistEdit;
                    ItemTrackingLines."Quantity (Base)".SetValue(LibraryRandom.RandInt(10));  // Take random for QuantityBase.
                    LibraryVariableStorage.Enqueue(ItemTrackingLines."Quantity (Base)".AsDEcimal);   // Enqueue Assigned Qantity.
                end;
            TrackingOption::AssignMoreThanPurchasedQty:
                begin
                    ItemTrackingLines."Lot No.".AssistEdit;
                    LibraryVariableStorage.Dequeue(QuantityBase);
                    ItemTrackingLines."Quantity (Base)".SetValue(QuantityBase);
                    ItemTrackingLines."Lot No.".AssistEdit;
                end;
            TrackingOption::SetNewLotNo:
                begin
                    LibraryVariableStorage.Dequeue(LotNo);
                    LibraryVariableStorage.Dequeue(NewLotNo);
                    ItemTrackingLines."Lot No.".SetValue(LotNo);
                    ItemTrackingLines."New Lot No.".SetValue(NewLotNo);
                    ItemTrackingLines."Quantity (Base)".SetValue(ItemTrackingLines.Quantity3.AsInteger);
                end;
            TrackingOption::EditSNValue:
                begin
                    LibraryVariableStorage.Dequeue(SN);
                    ItemTrackingLines."Serial No.".SetValue(SN);
                    ItemTrackingLines."Quantity (Base)".SetValue(ItemTrackingLines.Quantity3.AsInteger);
                end;
            TrackingOption::SetNewSN:
                begin
                    LibraryVariableStorage.Dequeue(SN);
                    LibraryVariableStorage.Dequeue(NewSN);
                    ItemTrackingLines."Serial No.".SetValue(SN);
                    ItemTrackingLines."New Serial No.".SetValue(NewSN);
                    ItemTrackingLines."Quantity (Base)".SetValue(ItemTrackingLines.Quantity3.AsInteger);
                end;
            TrackingOption::SetLotAndSerial:
                begin
                    LibraryVariableStorage.Dequeue(LotNo);
                    LibraryVariableStorage.Dequeue(SN);
                    LibraryVariableStorage.Dequeue(QuantityBase);
                    ItemTrackingLines."Lot No.".SetValue(LotNo);
                    ItemTrackingLines."Serial No.".SetValue(SN);
                    ItemTrackingLines."Quantity (Base)".SetValue(QuantityBase);
                end;
            TrackingOption::CheckExpDateControls:
                begin
                    ExpectedEditability := LibraryVariableStorage.DequeueBoolean();
                    Assert.AreEqual(ExpectedEditability, ItemTrackingLines."Expiration Date".Editable(), 'Expiration date is not editable');
                    Assert.AreEqual(ExpectedEditability, ItemTrackingLines."New Expiration Date".Editable(), 'New Expiration date is not editable');
                end;
        end;
        ItemTrackingLines.OK.Invoke;
    end;

    [ModalPageHandler]
    [Scope('OnPrem')]
    procedure ItemTrackingLinesExpiredLotPageHandler(var ItemTrackingLines: TestPage "Item Tracking Lines")
    begin
        ItemTrackingLines."Lot No.".SetValue(LibraryVariableStorage.DequeueText);
        ItemTrackingLines."Quantity (Base)".SetValue(ItemTrackingLines.Quantity3.AsInteger);
    end;

    [ModalPageHandler]
    [Scope('OnPrem')]
    procedure ItemTrackingLinesExpiredSerialNoPageHandler(var ItemTrackingLines: TestPage "Item Tracking Lines")
    begin
        ItemTrackingLines."Serial No.".SetValue(LibraryVariableStorage.DequeueText);
        ItemTrackingLines."Quantity (Base)".SetValue(ItemTrackingLines.Quantity3.AsInteger);
    end;

    [ModalPageHandler]
    [Scope('OnPrem')]
    procedure ItemTrackingSummaryPageHandler(var ItemTrackingSummary: TestPage "Item Tracking Summary")
    var
        CurrentPendingQuantity: Variant;
        Quantity: Variant;
        OptionValue: Variant;
        TotalAvailableQuantity: Variant;
        TotalRequestedQuantity: Variant;
        ExpirationDate: Variant;
        OptionString: Option SetQuantity,VerifyQuantity,VerifyExpirationDate,AssignQty,SelectEntries,ReSelectEntries;
        SummaryOption: Option;
    begin
        LibraryVariableStorage.Dequeue(OptionValue);  // Dequeue variable.
        SummaryOption := OptionValue;  // To convert Variant into Option.
        case SummaryOption of
            OptionString::SetQuantity:
                begin
                    LibraryVariableStorage.Dequeue(Quantity);
                    ItemTrackingSummary.First;
                    ItemTrackingSummary."Selected Quantity".SetValue(Quantity);
                end;
            OptionString::VerifyQuantity:
                begin
                    LibraryVariableStorage.Dequeue(Quantity);
                    ItemTrackingSummary."Selected Quantity".AssertEquals(Quantity);
                end;
            OptionString::VerifyExpirationDate:
                begin
                    LibraryVariableStorage.Dequeue(ExpirationDate);
                    ItemTrackingSummary."Expiration Date".AssertEquals(ExpirationDate);
                end;
            OptionString::ReSelectEntries:
                begin
                    LibraryVariableStorage.Dequeue(TotalAvailableQuantity);  // Dequeue variable.
                    LibraryVariableStorage.Dequeue(TotalRequestedQuantity);  // Dequeue variable.
                    LibraryVariableStorage.Dequeue(CurrentPendingQuantity);  // Dequeue variable.
                    ItemTrackingSummary."Total Available Quantity".AssertEquals(TotalAvailableQuantity);
                    ItemTrackingSummary."Total Requested Quantity".AssertEquals(TotalRequestedQuantity);
                    ItemTrackingSummary."Current Pending Quantity".AssertEquals(CurrentPendingQuantity);
                end;
        end;
        ItemTrackingSummary.OK.Invoke;
    end;

    [ModalPageHandler]
    [Scope('OnPrem')]
    procedure ItemTrackingListPageHandler(var ItemTrackingList: TestPage "Item Tracking List")
    begin
        ItemTrackingList.OK.Invoke;
    end;

    [MessageHandler]
    [Scope('OnPrem')]
    procedure MessageHandlerValidateMessage(Message: Text[1024])
    var
        ExpectedMessage: Variant;
    begin
        LibraryVariableStorage.Dequeue(ExpectedMessage);  // Dequeue variable.
        Assert.IsTrue(StrPos(Message, ExpectedMessage) > 0, Message);
    end;

    [ModalPageHandler]
    [Scope('OnPrem')]
    procedure ReservationPageHandler(var Reservation: TestPage Reservation)
    begin
        Reservation."Reserve from Current Line".Invoke;
        Reservation.OK.Invoke;
    end;

    [MessageHandler]
    [Scope('OnPrem')]
    procedure MessageHandler(Message: Text[1024])
    begin
    end;
}

