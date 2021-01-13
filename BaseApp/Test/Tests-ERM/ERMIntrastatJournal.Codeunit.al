codeunit 134150 "ERM Intrastat Journal"
{
    Subtype = Test;
    TestPermissions = Disabled;

    trigger OnRun()
    begin
        // [FEATURE] [Intrastat]
        IsInitialized := false;
    end;

    var
        Assert: Codeunit Assert;
        LibraryTestInitialize: Codeunit "Library - Test Initialize";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryERM: Codeunit "Library - ERM";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibrarySales: Codeunit "Library - Sales";
        LibraryFiscalYear: Codeunit "Library - Fiscal Year";
        LibraryUtility: Codeunit "Library - Utility";
        LibraryPatterns: Codeunit "Library - Patterns";
        LibraryVariableStorage: Codeunit "Library - Variable Storage";
        LibraryRandom: Codeunit "Library - Random";
        LibraryMarketing: Codeunit "Library - Marketing";
        LibraryJob: Codeunit "Library - Job";
        LibraryWarehouse: Codeunit "Library - Warehouse";
        IsInitialized: Boolean;
        ValidationErr: Label '%1 must be %2 in %3.';
        LineNotExistErr: Label 'Intrastat Journal Lines incorrectly created.';
        LineCountErr: Label 'The number of %1 entries is incorrect.';
        InternetURLTxt: Label 'www.microsoft.com';
        InvalidURLTxt: Label 'URL must be prefix with http.';
        PackageTrackingNoErr: Label 'Package Tracking No does not exist.';
        HttpTxt: Label 'http://';
        OnDelIntrastatContactErr: Label 'You cannot delete contact number %1 because it is set up as an Intrastat contact in the Intrastat Setup window.', Comment = '1 - Contact No';
        OnDelVendorIntrastatContactErr: Label 'You cannot delete vendor number %1 because it is set up as an Intrastat contact in the Intrastat Setup window.', Comment = '1 - Vendor No';
        ShptMethodCodeErr: Label 'Wrong Shipment Method Code';

    [Test]
    [Scope('OnPrem')]
    procedure ItemLedgerEntryForPurchase()
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        PurchaseLine: Record "Purchase Line";
        DocumentNo: Code[20];
    begin
        // [FEATURE] [Purchase]
        // [SCENARIO] Check Item Ledger Entry after posting Purchase Order.

        // [GIVEN] Posted Purchase Order
        Initialize;
        DocumentNo := CreateAndPostPurchaseOrder(PurchaseLine, WorkDate);

        // [THEN] Verify Item Ledger Entry
        VerifyItemLedgerEntry(ItemLedgerEntry."Document Type"::"Purchase Receipt", DocumentNo, GetCountryRegionCode, PurchaseLine.Quantity);
    end;

    [Test]
    [Scope('OnPrem')]
    procedure IntrastatLineForPurchase()
    var
        PurchaseLine: Record "Purchase Line";
        IntrastatJnlLine: Record "Intrastat Jnl. Line";
        DocumentNo: Code[20];
    begin
        // [FEATURE] [Purchase]
        // [SCENARIO] Check Intrastat Journal Line for posted Purchase Order.

        // [GIVEN] Posted Purchase Order
        Initialize;
        DocumentNo := CreateAndPostPurchaseOrder(PurchaseLine, WorkDate);

        // [WHEN] Get Intrastat Journal Line for Purchase Order
        // [THEN] Verify Intrastat Journal Line
        CreateAndVerifyIntrastatLine(DocumentNo, PurchaseLine."No.", PurchaseLine.Quantity, IntrastatJnlLine.Type::Receipt);
    end;

    [Test]
    [Scope('OnPrem')]
    procedure NoIntrastatLineForPurchase()
    var
        PurchaseLine: Record "Purchase Line";
    begin
        // [FEATURE] [Purchase]
        // [SCENARIO] Check no Intrastat Journal Line exist after Deleting them for Purchase Order.

        // [GIVEN] Posted Purchase Order
        Initialize;
        CreateAndPostPurchaseOrder(PurchaseLine, WorkDate);

        // [WHEN] Create Intrastat Journal Lines, Delete them
        // [THEN] Verify that no Intrastat Journal Lines exist for Posted Purchase Order.
        DeleteAndVerifyNoIntrastatLine;
    end;

    [Test]
    [HandlerFunctions('UndoDocumentConfirmHandler')]
    [Scope('OnPrem')]
    procedure UndoPurchaseReceipt()
    var
        PurchaseLine: Record "Purchase Line";
        PurchRcptLine: Record "Purch. Rcpt. Line";
        DocumentNo: Code[20];
    begin
        // [FEATURE] [Purchase]
        // [SCENARIO] Check Quantity on Purchase Receipt Line after doing Undo Purchase Order.

        // [GIVEN] Posted Purchase Order
        Initialize;
        DocumentNo := CreateAndPostPurchaseOrder(PurchaseLine, WorkDate);

        // [WHEN] Undo Purchase Receipt Line
        UndoPurchaseReceiptLine(DocumentNo, PurchaseLine."No.");

        // [THEN] Verify Undone Quantity on Purchase Receipt Line.
        PurchRcptLine.SetRange("Document No.", DocumentNo);
        PurchRcptLine.SetFilter("Appl.-to Item Entry", '<>0');
        PurchRcptLine.FindFirst;
        Assert.AreEqual(
          -PurchaseLine.Quantity, PurchRcptLine.Quantity, StrSubstNo(ValidationErr,
            PurchRcptLine.FieldCaption(Quantity), -PurchaseLine.Quantity, PurchRcptLine.TableCaption));
    end;

    [Test]
    [HandlerFunctions('UndoDocumentConfirmHandler')]
    [Scope('OnPrem')]
    procedure IntrastatLineAfterUndoPurchase()
    var
        PurchaseLine: Record "Purchase Line";
        DocumentNo: Code[20];
    begin
        // [FEATURE] [Purchase]
        // [SCENARIO] Check that no Intrastat Line exist for the Item for which Undo Purchase Receipt has done.

        // [GIVEN] Create and Post Purchase Order
        Initialize;
        DocumentNo := CreateAndPostPurchaseOrder(PurchaseLine, WorkDate);

        // [WHEN] Undo Purchase Receipt Line
        UndoPurchaseReceiptLine(DocumentNo, PurchaseLine."No.");

        // [WHEN] Create Intrastat Journal Template, Batch and Get Entries for Intrastat Journal Line
        // [THEN] Verify no entry exists for posted Item.
        GetEntriesAndVerifyNoItemLine(DocumentNo, PurchaseLine."No.");
    end;

    [Test]
    [Scope('OnPrem')]
    procedure ItemLedgerEntryForSales()
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        SalesLine: Record "Sales Line";
        DocumentNo: Code[20];
    begin
        // [FEATURE] [Sales]
        // [SCENARIO] Check Item Ledger Entry after posting Sales Order.

        // [GIVEN] Create and Post Sales Order
        Initialize;
        DocumentNo := CreateAndPostSalesOrder(SalesLine, WorkDate);

        // [THEN] Verify Item Ledger Entry
        VerifyItemLedgerEntry(ItemLedgerEntry."Document Type"::"Sales Shipment", DocumentNo, GetCountryRegionCode, -SalesLine.Quantity);
    end;

    [Test]
    [Scope('OnPrem')]
    procedure IntrastatLineForSales()
    var
        SalesLine: Record "Sales Line";
        IntrastatJnlLine: Record "Intrastat Jnl. Line";
        DocumentNo: Code[20];
    begin
        // [FEATURE] [Sales]
        // [SCENARIO] Check Intrastat Journal Line for posted Sales Order.

        // [GIVEN] Create and Post Sales Order
        Initialize;
        DocumentNo := CreateAndPostSalesOrder(SalesLine, WorkDate);

        // [WHEN] Get Intrastat Journal Lines for Sales Order
        // [THEN] Verify Intrastat Journal Line
        CreateAndVerifyIntrastatLine(DocumentNo, SalesLine."No.", SalesLine.Quantity, IntrastatJnlLine.Type::Shipment);
    end;

    [Test]
    [Scope('OnPrem')]
    procedure NoIntrastatLineForSales()
    var
        SalesLine: Record "Sales Line";
    begin
        // [FEATURE] [Sales]
        // [SCENARIO] Check no Intrastat Journal Line exist after Deleting them for Sales Shipment.

        // [GIVEN] Take Starting Date as WORKDATE and Random Ending Date based on WORKDATE.
        Initialize;
        CreateAndPostSalesOrder(SalesLine, WorkDate);

        // [WHEN] Intrastat Journal Lines, Delete them
        // [THEN] Verify that no lines exist for Posted Sales Order.
        DeleteAndVerifyNoIntrastatLine;
    end;

    [Test]
    [HandlerFunctions('UndoDocumentConfirmHandler')]
    [Scope('OnPrem')]
    procedure UndoSalesShipment()
    var
        SalesLine: Record "Sales Line";
        SalesShipmentLine: Record "Sales Shipment Line";
        DocumentNo: Code[20];
    begin
        // [FEATURE] [Sales]
        // [SCENARIO] Check Quantity on Sales Shipment Line after doing Undo Sales Shipment.

        // [GIVEN] Posted Sales Order
        Initialize;
        DocumentNo := CreateAndPostSalesOrder(SalesLine, WorkDate);

        // [WHEN] Undo Sales Shipment Line
        UndoSalesShipmentLine(DocumentNo, SalesLine."No.");

        // [THEN] Verify Undone Quantity on Sales Shipment Line.
        SalesShipmentLine.SetRange("Document No.", DocumentNo);
        SalesShipmentLine.SetFilter("Appl.-from Item Entry", '<>0');
        SalesShipmentLine.FindFirst;
        Assert.AreEqual(
          -SalesLine.Quantity, SalesShipmentLine.Quantity,
          StrSubstNo(ValidationErr, SalesShipmentLine.FieldCaption(Quantity), -SalesLine.Quantity, SalesShipmentLine.TableCaption));
    end;

    [Test]
    [HandlerFunctions('UndoDocumentConfirmHandler')]
    [Scope('OnPrem')]
    procedure IntrastatLineAfterUndoSales()
    var
        SalesLine: Record "Sales Line";
        DocumentNo: Code[20];
    begin
        // [FEATURE] [Sales]
        // [SCENARIO] Check that no Intrastat Line exist for the Item for which Undo Sales Shipment has done.

        // [GIVEN] Create and Post Sales Order and undo Sales Shipment Line.
        Initialize;
        DocumentNo := CreateAndPostSalesOrder(SalesLine, WorkDate);
        UndoSalesShipmentLine(DocumentNo, SalesLine."No.");

        // [WHEN] Create Intrastat Journal Template, Batch and Get Entries for Intrastat Journal Line
        // [THEN] Verify no entry exists for posted Item.
        GetEntriesAndVerifyNoItemLine(DocumentNo, SalesLine."No.");
    end;

    [Test]
    [HandlerFunctions('IntrastatJnlTemplateListPageHandler,GetItemLedgerEntriesReportHandler')]
    [Scope('OnPrem')]
    procedure IntrastatJournalWithPurchaseOrder()
    var
        PurchaseLine: Record "Purchase Line";
        IntrastatJnlBatch: Record "Intrastat Jnl. Batch";
        SecondIntrastatJnlBatch: Record "Intrastat Jnl. Batch";
        IntrastatJournal: TestPage "Intrastat Journal";
        NewPostingDate: Date;
    begin
        // [FEATURE] [Purchase]
        // [SCENARIO] Check Intrastat Journal Entries after Posting Purchase Order and Get Entries with New Posting Date.

        // [GIVEN] Create Purchase Order with New Posting Date and Create New Batch and Template for Intrastat Journal with difference with 1 Year.
        Initialize;
        NewPostingDate := CalcDate('<' + Format(LibraryRandom.RandInt(5)) + 'Y>', WorkDate);
        CreateAndPostPurchaseOrder(PurchaseLine, NewPostingDate);

        // [GIVEN] Two Intrastat Journal Batches for the same period
        LibraryERM.CreateIntrastatJnlTemplateAndBatch(IntrastatJnlBatch, NewPostingDate);
        LibraryERM.CreateIntrastatJnlTemplateAndBatch(SecondIntrastatJnlBatch, NewPostingDate);

        Commit();  // Commit is required to commit the posted entries.
        LibraryVariableStorage.Enqueue(IntrastatJnlBatch."Journal Template Name");
        LibraryVariableStorage.Enqueue(true); // Show Item Charge entries

        // [WHEN] Get Entries from Intrastat Journal pages for two Batches with the same period with "Show item charge entries" options set to TRUE
        // use created "Journal Template Name" in IntrastatJnlTemplateListPageHandler
        IntrastatJournal.OpenEdit;
        IntrastatJournal.GetEntries.Invoke;

        // [THEN] Verify that Entry values on Intrastat Journal Page match Purchase Line values
        IntrastatJournal.FILTER.SetFilter("Item No.", PurchaseLine."No.");
        IntrastatJournal.Type.AssertEquals(Format(IntrastatJournal.Type.GetOption(1))); // Option 1 for Receipt Value.
        IntrastatJournal.Quantity.AssertEquals(PurchaseLine.Quantity);
        IntrastatJournal.Date.AssertEquals(NewPostingDate);

        // [THEN] No Entries suggested in a second Intrastat Journal
        // added verification for TFS 375494 scenario
        LibraryVariableStorage.Enqueue(SecondIntrastatJnlBatch."Journal Template Name");
        LibraryVariableStorage.Enqueue(true); // Show Item Charge entries
        OpenAndVerifyIntrastatJournalLine(SecondIntrastatJnlBatch.Name, PurchaseLine."No.", false);

        IntrastatJnlBatch.Delete(true);
        SecondIntrastatJnlBatch.Delete(true);
    end;

    [Test]
    [HandlerFunctions('IntrastatJnlTemplateListPageHandler,GetItemLedgerEntriesReportHandler')]
    [Scope('OnPrem')]
    procedure IntrastatJournalWithItemChargeAssignmentAfterPurchaseCreditMemo()
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        ChargePurchaseLine: Record "Purchase Line";
        IntrastatJnlBatch: Record "Intrastat Jnl. Batch";
        ChargeIntrastatJnlBatch: Record "Intrastat Jnl. Batch";
        IntrastatJournal: TestPage "Intrastat Journal";
        NewPostingDate: Date;
        DocumentNo: Code[20];
    begin
        // [FEATURE] [Purchase]
        // [SCENARIO] Check Intrastat Journal Entries after Posting Purchase Order, Purchase Credit Memo with Item Charge Assignment and Get Entries with New Posting Date.
        Initialize;

        // [GIVEN] Create and Post Purchase Order on January with Amount = "X"
        NewPostingDate := CalcDate('<' + Format(LibraryRandom.RandInt(5)) + 'Y>', WorkDate);
        DocumentNo := CreateAndPostPurchaseOrder(PurchaseLine, NewPostingDate);

        // [GIVEN] Create and Post Purchase Credit Memo with Item Charge Assignment on February.
        CreatePurchaseHeader(
          PurchaseHeader, PurchaseHeader."Document Type"::"Credit Memo",
          CalcDate('<1M>', NewPostingDate), CreateVendor(GetCountryRegionCode));
        PurchaseHeader.Validate("Vendor Cr. Memo No.", PurchaseHeader."No.");
        PurchaseHeader.Modify(true);
        CreatePurchaseLine(
          PurchaseHeader, ChargePurchaseLine, ChargePurchaseLine.Type::"Charge (Item)", LibraryInventory.CreateItemChargeNo);
        CreateItemChargeAssignmentForPurchaseCreditMemo(ChargePurchaseLine, DocumentNo);
        LibraryPurchase.PostPurchaseDocument(PurchaseHeader, true, false);

        // [GIVEN] Two Intrastat Journal Batches for January and February with "Show item charge entries" options set to TRUE
        LibraryERM.CreateIntrastatJnlTemplateAndBatch(IntrastatJnlBatch, NewPostingDate);
        LibraryERM.CreateIntrastatJnlTemplateAndBatch(ChargeIntrastatJnlBatch, PurchaseHeader."Posting Date");
        Commit();
        LibraryVariableStorage.Enqueue(IntrastatJnlBatch."Journal Template Name");
        LibraryVariableStorage.Enqueue(true); // Show Item Charge entries

        // [WHEN] User runs Get Entries in Intrastat Journal for January and February
        // use created "Journal Template Name" in IntrastatJnlTemplateListPageHandler
        InvokeGetEntriesOnIntrastatJnl(IntrastatJournal, IntrastatJnlBatch.Name);

        // [THEN] Item Charge Entry suggested for February, "Intrastat Journal Line" has Amount = "X" for January
        LibraryVariableStorage.Enqueue(ChargeIntrastatJnlBatch."Journal Template Name");
        LibraryVariableStorage.Enqueue(true); // Show Item Charge entries
        LibraryVariableStorage.Enqueue(IntrastatJnlBatch.Name);
        OpenAndVerifyIntrastatJournalLine(ChargeIntrastatJnlBatch.Name, PurchaseLine."No.", true);
        IntrastatJournal.FILTER.SetFilter("Item No.", PurchaseLine."No.");
        IntrastatJournal.Amount.AssertEquals(PurchaseLine.Amount);

        IntrastatJnlBatch.Delete(true);
        ChargeIntrastatJnlBatch.Delete(true);
    end;

    [Test]
    [HandlerFunctions('IntrastatJnlTemplateListPageHandler,GetItemLedgerEntriesReportHandler')]
    [Scope('OnPrem')]
    procedure IntrastatJournalWithSalesOrder()
    var
        SalesLine: Record "Sales Line";
        IntrastatJnlBatch: Record "Intrastat Jnl. Batch";
        IntrastatJournal: TestPage "Intrastat Journal";
        NewPostingDate: Date;
    begin
        // [FEATURE] [Sales]
        // [SCENARIO] Check Intrastat Journal Entries after Posting Sales Order and Get Entries with New Posting Date.

        // [GIVEN] Create Sales Order with New Posting Date and Create New Batch and Template for Intrastat Journal.
        Initialize;
        NewPostingDate := CalcDate('<' + Format(LibraryRandom.RandInt(5)) + 'Y>', WorkDate);
        CreateAndPostSalesOrder(SalesLine, NewPostingDate);
        LibraryERM.CreateIntrastatJnlTemplateAndBatch(IntrastatJnlBatch, NewPostingDate);
        Commit();  // Commit is required to commit the posted entries.
        LibraryVariableStorage.Enqueue(IntrastatJnlBatch."Journal Template Name");

        // [WHEN] Get Entries from Intrastat Journal page with "Show item charge entries" options set to TRUE.
        LibraryVariableStorage.Enqueue(true); // Show Item Charge entries
        IntrastatJournal.OpenEdit;
        IntrastatJournal.GetEntries.Invoke;

        // [THEN] Verify Entries on Intrastat Journal Page.
        IntrastatJournal.FILTER.SetFilter("Item No.", SalesLine."No.");
        IntrastatJournal.Type.AssertEquals(Format(IntrastatJournal.Type.GetOption(2))); // Option 2 for Shipment Value.
        IntrastatJournal.Quantity.AssertEquals(SalesLine.Quantity);
        IntrastatJournal.Date.AssertEquals(NewPostingDate);

        IntrastatJnlBatch.Delete(true);
    end;

    [Test]
    [HandlerFunctions('IntrastatJnlTemplateListPageHandler,GetItemLedgerEntriesReportHandler')]
    [Scope('OnPrem')]
    procedure IntrastatJournalWithItemChargeAssignmentAfterSalesCreditMemo()
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        IntrastatJnlBatch: Record "Intrastat Jnl. Batch";
        NewPostingDate: Date;
        DocumentNo: Code[20];
    begin
        // [FEATURE] [Sales] [Item Charge]
        // [SCENARIO] Check Intrastat Journal Entries after Posting Sales Order, Sales Credit Memo with Item Charge Assignment and Get Entries with New Posting Date.

        // [GIVEN] Create and Post Sales Order with New Posting Date with different 1 Year.
        Initialize;
        NewPostingDate := CalcDate('<' + Format(LibraryRandom.RandInt(5)) + 'Y>', WorkDate);
        DocumentNo := CreateAndPostSalesOrder(SalesLine, NewPostingDate);

        // [GIVEN] Create and Sales Credit Memo with Item Charge Assign Ment with different Posting Date. 1M is required for Sales Credit Memo.
        CreateSalesDocument(
          SalesLine, CalcDate('<1M>', NewPostingDate), SalesLine."Document Type"::"Credit Memo", SalesLine.Type::"Charge (Item)",
          LibraryInventory.CreateItemChargeNo, 1);
        SalesHeader.Get(SalesLine."Document Type", SalesLine."Document No.");
        CreateItemChargeAssignmentForSalesCreditMemo(SalesLine, DocumentNo);
        LibrarySales.PostSalesDocument(SalesHeader, true, true);
        LibraryERM.CreateIntrastatJnlTemplateAndBatch(IntrastatJnlBatch, SalesHeader."Posting Date");
        LibraryVariableStorage.Enqueue(IntrastatJnlBatch."Journal Template Name");

        // [WHEN] Open Intrastat Journal Line Page and Get Entries through IntrastatJnlTemplateListPageHandler and GetItemLedgerEntriesReportHandler with "Show item charge entries" options set to TRUE
        // [THEN] Verify Intrastat Journal Entry
        LibraryVariableStorage.Enqueue(true); // Show Item Charge entries
        OpenAndVerifyIntrastatJournalLine(IntrastatJnlBatch.Name, SalesLine."No.", false);

        IntrastatJnlBatch.Delete(true);
    end;

    [Test]
    [Scope('OnPrem')]
    procedure TotalWeightOnIntrastatJournalLine()
    var
        IntrastatJnlLine: Record "Intrastat Jnl. Line";
        NetWeight: Decimal;
    begin
        // [SCENARIO] Check Intrastat Journal Total Weight after entering Quantity on Intrastat Journal Line.

        // [GIVEN] Intrastat Journal Line
        Initialize;
        CreateIntrastatJnlLine(IntrastatJnlLine);

        // [WHEN] Create and Update Quantity on Intrastat Journal Line.
        NetWeight := UseItemNonZeroNetWeight(IntrastatJnlLine);

        // [THEN] Verify Total Weight correctly calculated on Intrastat Journal Line.
        IntrastatJnlLine.TestField("Total Weight", IntrastatJnlLine.Quantity * NetWeight);
    end;

    [Test]
    [Scope('OnPrem')]
    procedure TestPackageNoIsIncludedInInternetAddressLink()
    var
        SalesShipmentHeader: Record "Sales Shipment Header";
    begin
        Initialize;
        CreateSalesShipmentHeader(SalesShipmentHeader, '%1');
        Assert.AreEqual(
          SalesShipmentHeader."Package Tracking No.", CopyStr(SalesShipmentHeader.GetTrackingInternetAddr, StrLen(HttpTxt) + 1),
          PackageTrackingNoErr);
    end;

    [Test]
    [Scope('OnPrem')]
    procedure TestInternetAddressWithoutHttp()
    var
        SalesShipmentHeader: Record "Sales Shipment Header";
    begin
        Initialize;
        CreateSalesShipmentHeader(SalesShipmentHeader, InternetURLTxt);
        Assert.AreEqual(HttpTxt + InternetURLTxt, SalesShipmentHeader.GetTrackingInternetAddr, InvalidURLTxt);
    end;

    [Test]
    [Scope('OnPrem')]
    procedure TestInternetAddressWithHttp()
    var
        SalesShipmentHeader: Record "Sales Shipment Header";
    begin
        Initialize;
        CreateSalesShipmentHeader(SalesShipmentHeader, HttpTxt + InternetURLTxt);
        Assert.AreEqual(HttpTxt + InternetURLTxt, SalesShipmentHeader.GetTrackingInternetAddr, InvalidURLTxt);
    end;

    [Test]
    [Scope('OnPrem')]
    procedure TestNoPackageNoExistIfNoPlaceHolderExistInURL()
    var
        SalesShipmentHeader: Record "Sales Shipment Header";
    begin
        Initialize;
        CreateSalesShipmentHeader(SalesShipmentHeader, InternetURLTxt);
        Assert.IsTrue(
          StrPos(SalesShipmentHeader.GetTrackingInternetAddr, SalesShipmentHeader."Package Tracking No.") = 0, PackageTrackingNoErr);
    end;

    [Test]
    [HandlerFunctions('IntrastatJnlTemplateListPageHandler,GetItemLedgerEntriesReportHandler')]
    [Scope('OnPrem')]
    procedure VerifyNoIntraLinesCreatedForCrossedBoardItemChargeInNextPeriod()
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        IntrastatJnlBatch: Record "Intrastat Jnl. Batch";
        NextIntrastatJnlBatch: Record "Intrastat Jnl. Batch";
        DocumentNo: Code[20];
        ItemNo: Code[20];
        InvoicePostingDate: Date;
    begin
        // [FEATURE] [Purchase] [Item Charge]
        // [SCENARIO 376161] Invoice and Item Charge suggested for Intrastat Journal in different Periods - Cross-Border
        Initialize;

        // [GIVEN] Posted Purchase Invoice in "Y" period - Cross-border
        InvoicePostingDate := CalcDate('<' + Format(LibraryRandom.RandInt(5)) + 'Y>', WorkDate);
        DocumentNo := CreateAndPostPurchaseOrder(PurchaseLine, InvoicePostingDate);
        ItemNo := PurchaseLine."No.";

        // [GIVEN] Posted Item Charge in "F" period
        CreatePurchaseHeader(
          PurchaseHeader, PurchaseHeader."Document Type"::Invoice,
          CalcDate('<1M>', InvoicePostingDate), CreateVendor(GetCountryRegionCode));
        CreatePurchaseLine(
          PurchaseHeader, PurchaseLine, PurchaseLine.Type::"Charge (Item)", LibraryInventory.CreateItemChargeNo);
        CreateItemChargeAssignmentForPurchaseCreditMemo(PurchaseLine, DocumentNo);
        LibraryPurchase.PostPurchaseDocument(PurchaseHeader, true, false);

        // [GIVEN] Intrastat Batches for "Y" and "F" period
        LibraryERM.CreateIntrastatJnlTemplateAndBatch(IntrastatJnlBatch, InvoicePostingDate);
        LibraryERM.CreateIntrastatJnlTemplateAndBatch(NextIntrastatJnlBatch, PurchaseHeader."Posting Date");
        LibraryVariableStorage.Enqueue(IntrastatJnlBatch."Journal Template Name");
        LibraryVariableStorage.Enqueue(true); // Show Item Charge entries

        // [WHEN] Entries suggested to Intrastat Journal "J" and "F" with "Show item charge entries" options set to TRUE
        // [THEN] Intrastat Journal "J" contains 1 line for Posted Invoice
        // [THEN] Intrastat Journal "F" contains 1 line for Posted Item Charge
        OpenAndVerifyIntrastatJournalLine(IntrastatJnlBatch.Name, ItemNo, true);
        LibraryVariableStorage.Enqueue(NextIntrastatJnlBatch."Journal Template Name");
        LibraryVariableStorage.Enqueue(true); // Show Item Charge entries
        OpenAndVerifyIntrastatJournalLine(NextIntrastatJnlBatch.Name, ItemNo, true);

        IntrastatJnlBatch.Delete(true);
        NextIntrastatJnlBatch.Delete(true);
    end;

    [Test]
    [HandlerFunctions('IntrastatJnlTemplateListPageHandler,GetItemLedgerEntriesReportHandler')]
    [Scope('OnPrem')]
    procedure VerifyIntrastatJournalLineSuggestedForNonCrossedBoardItemChargeInNextPeriod()
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        ItemCharge: Record "Item Charge";
        IntrastatJnlBatch: Record "Intrastat Jnl. Batch";
        NextIntrastatJnlBatch: Record "Intrastat Jnl. Batch";
        CompanyInformation: Record "Company Information";
        DocumentNo: Code[20];
        ItemNo: Code[20];
        InvoicePostingDate: Date;
    begin
        // [FEATURE] [Purchase] [Item Charge]
        // [SCENARIO 376161] Invoice and Item Charge not suggested for Intrastat Journal in different Periods - Not Cross-Border
        Initialize;
        InvoicePostingDate := CalcDate('<' + Format(LibraryRandom.RandInt(5)) + 'Y>', WorkDate);

        // [GIVEN] Posted Purchase Invoice in "Y" period - Not Cross-border
        CompanyInformation.Get();
        CreatePurchaseHeader(
          PurchaseHeader, PurchaseHeader."Document Type"::Order, InvoicePostingDate,
          CreateVendor(CompanyInformation."Country/Region Code"));
        CreatePurchaseLine(PurchaseHeader, PurchaseLine, PurchaseLine.Type::Item, CreateItem);
        ItemNo := PurchaseLine."No.";
        DocumentNo := LibraryPurchase.PostPurchaseDocument(PurchaseHeader, true, false);

        // [GIVEN] Posted Item Charge in "F" period
        CreatePurchaseHeader(
          PurchaseHeader, PurchaseHeader."Document Type"::Invoice, CalcDate('<1M>', InvoicePostingDate),
          PurchaseHeader."Buy-from Vendor No.");
        LibraryInventory.CreateItemCharge(ItemCharge);
        CreatePurchaseLine(PurchaseHeader, PurchaseLine, PurchaseLine.Type::"Charge (Item)", ItemCharge."No.");
        CreateItemChargeAssignmentForPurchaseCreditMemo(PurchaseLine, DocumentNo);
        LibraryPurchase.PostPurchaseDocument(PurchaseHeader, true, false);

        // [GIVEN] Intrastat Batches for "Y" and "F" period
        LibraryERM.CreateIntrastatJnlTemplateAndBatch(IntrastatJnlBatch, InvoicePostingDate);
        LibraryERM.CreateIntrastatJnlTemplateAndBatch(NextIntrastatJnlBatch, PurchaseHeader."Posting Date");
        LibraryVariableStorage.Enqueue(IntrastatJnlBatch."Journal Template Name");
        LibraryVariableStorage.Enqueue(true); // Show Item Charge entries

        // [WHEN] Entries suggested to Intrastat Journal "J" and "F" with "Show item charge entries" options set to TRUE
        // [THEN] Intrastat Journal "J" contains no lines
        // [THEN] Intrastat Journal "F" contains no lines
        OpenAndVerifyIntrastatJournalLine(IntrastatJnlBatch.Name, ItemNo, false);
        LibraryVariableStorage.Enqueue(NextIntrastatJnlBatch."Journal Template Name");
        LibraryVariableStorage.Enqueue(true); // Show Item Charge entries
        OpenAndVerifyIntrastatJournalLine(NextIntrastatJnlBatch.Name, ItemNo, false);

        IntrastatJnlBatch.Delete(true);
        NextIntrastatJnlBatch.Delete(true);
    end;

    [Test]
    [HandlerFunctions('UndoDocumentConfirmHandler')]
    [Scope('OnPrem')]
    procedure IntrastatGetEntriesUndoReceiptSameItem()
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        IntrastatJnlLine: Record "Intrastat Jnl. Line";
        DocumentNo: Code[20];
        NoOfPurchaseLines: Integer;
    begin
        // [FEATURE] [Purchase]
        // [SCENARIO 121966] Get Entries for Intrastat doesn't suggest Purchase Receipt lines that were Corrected
        Initialize;
        // [GIVEN] Posted(Receipt) Purchase Order with lines for the same Item
        NoOfPurchaseLines := LibraryRandom.RandIntInRange(2, 10);
        DocumentNo :=
          CreateAndPostPurchaseDocumentMultiLine(
            PurchaseLine, PurchaseHeader."Document Type"::Order, WorkDate, CreateItem, NoOfPurchaseLines);
        // [GIVEN] Undo Receipt for one of the lines (random) and finally post Purchase Order
        UndoPurchaseReceiptLineByLineNo(DocumentNo, LibraryRandom.RandInt(NoOfPurchaseLines));
        PurchaseHeader.Get(PurchaseLine."Document Type", PurchaseLine."Document No.");
        LibraryPurchase.PostPurchaseDocument(PurchaseHeader, false, true);
        // [WHEN] User runs Get Entries for Intrastat Journal
        CreateIntrastatJnlLineAndGetEntries(IntrastatJnlLine, WorkDate, WorkDate);
        // [THEN] Only lines for which Undo Receipt was not done are suggested
        VerifyNoOfIntrastatLinesForDocumentNo(
          IntrastatJnlLine."Journal Template Name", IntrastatJnlLine."Journal Batch Name",
          DocumentNo, NoOfPurchaseLines - 1);
    end;

    [Test]
    [HandlerFunctions('UndoDocumentConfirmHandler')]
    [Scope('OnPrem')]
    procedure IntrastatGetEntriesUndoShipmentSameItem()
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        IntrastatJnlLine: Record "Intrastat Jnl. Line";
        DocumentNo: Code[20];
        NoOfSalesLines: Integer;
    begin
        // [FEATURE] [Sales]
        // [SCENARIO 121966] Get Entries for Intrastat doesn't suggest Sales Shipment lines that were Corrected
        Initialize;
        NoOfSalesLines := LibraryRandom.RandIntInRange(2, 10);
        // [GIVEN] Posted(Shipment) Sales Order with lines for the same Item
        DocumentNo :=
          CreateAndPostSalesDocumentMultiLine(
            SalesLine, SalesLine."Document Type"::Order, WorkDate, CreateItem, NoOfSalesLines);
        // [GIVEN] Undo Receipt for one of the lines (random) and finally post Sales Order
        UndoSalesShipmentLineByLineNo(DocumentNo, LibraryRandom.RandInt(NoOfSalesLines));
        SalesHeader.Get(SalesLine."Document Type", SalesLine."Document No.");
        LibrarySales.PostSalesDocument(SalesHeader, false, true);
        // [WHEN] User runs Get Entries for Intrastat Journal
        CreateIntrastatJnlLineAndGetEntries(IntrastatJnlLine, WorkDate, WorkDate);
        // [THEN] Only lines for which Undo Receipt was not done are suggested
        VerifyNoOfIntrastatLinesForDocumentNo(
          IntrastatJnlLine."Journal Template Name", IntrastatJnlLine."Journal Batch Name",
          DocumentNo, NoOfSalesLines - 1);
    end;

    [Test]
    [HandlerFunctions('UndoDocumentConfirmHandler')]
    [Scope('OnPrem')]
    procedure IntrastatGetEntriesUndoReturnShipmentSameItem()
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        IntrastatJnlLine: Record "Intrastat Jnl. Line";
        DocumentNo: Code[20];
        NoOfPurchaseLines: Integer;
    begin
        // [FEATURE] [Purchase]
        // [SCENARIO 121966] Get Entries for Intrastat doesn't suggest Return Shipment lines that were Corrected
        Initialize;
        // [GIVEN] Posted(Shipment) Purchase Order with lines for the same Item
        NoOfPurchaseLines := LibraryRandom.RandIntInRange(2, 10);
        DocumentNo :=
          CreateAndPostPurchaseDocumentMultiLine(
            PurchaseLine, PurchaseHeader."Document Type"::"Return Order", WorkDate, CreateItem, NoOfPurchaseLines);
        // [GIVEN] Undo Receipt for one of the lines (random) and finally post Return Order
        UndoReturnShipmentLineByLineNo(DocumentNo, LibraryRandom.RandInt(NoOfPurchaseLines));
        PurchaseHeader.Get(PurchaseLine."Document Type", PurchaseLine."Document No.");
        PurchaseHeader.Validate("Vendor Cr. Memo No.", PurchaseHeader."No.");
        PurchaseHeader.Modify(true);
        LibraryPurchase.PostPurchaseDocument(PurchaseHeader, false, true);
        // [WHEN] User runs Get Entries for Intrastat Journal
        CreateIntrastatJnlLineAndGetEntries(IntrastatJnlLine, WorkDate, WorkDate);
        // [THEN] Only lines for which Undo Receipt was not done are suggested
        VerifyNoOfIntrastatLinesForDocumentNo(
          IntrastatJnlLine."Journal Template Name", IntrastatJnlLine."Journal Batch Name",
          DocumentNo, NoOfPurchaseLines - 1);
    end;

    [Test]
    [HandlerFunctions('UndoDocumentConfirmHandler')]
    [Scope('OnPrem')]
    procedure IntrastatGetEntriesUndoReturnReceiptSameItem()
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        IntrastatJnlLine: Record "Intrastat Jnl. Line";
        DocumentNo: Code[20];
        NoOfSalesLines: Integer;
    begin
        // [FEATURE] [Sales]
        // [SCENARIO 121966] Get Entries for Intrastat doesn't suggest Return Receipt lines that were Corrected
        Initialize;
        // [GIVEN] Posted(Receipt) Sales Return Order with lines for the same Item
        NoOfSalesLines := LibraryRandom.RandIntInRange(2, 10);
        DocumentNo :=
          CreateAndPostSalesDocumentMultiLine(
            SalesLine, SalesLine."Document Type"::"Return Order", WorkDate, CreateItem, NoOfSalesLines);
        // [GIVEN] Undo Receipt for one of the lines (random) and finally post Return Order
        UndoReturnReceiptLineByLineNo(DocumentNo, LibraryRandom.RandInt(NoOfSalesLines));
        SalesHeader.Get(SalesLine."Document Type", SalesLine."Document No.");
        LibrarySales.PostSalesDocument(SalesHeader, false, true);
        // [WHEN] User runs Get Entries for Intrastat Journal
        CreateIntrastatJnlLineAndGetEntries(IntrastatJnlLine, WorkDate, WorkDate);
        // [THEN] Only lines for which Undo Receipt was not done are suggested
        VerifyNoOfIntrastatLinesForDocumentNo(
          IntrastatJnlLine."Journal Template Name", IntrastatJnlLine."Journal Batch Name",
          DocumentNo, NoOfSalesLines - 1);
    end;

    [Test]
    [HandlerFunctions('IntrastatJnlTemplateListPageHandler,GetItemLedgerEntriesReportHandler')]
    [Scope('OnPrem')]
    procedure IntrastatJournalWithItemChargeOnStartDate()
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        IntrastatJnlBatch: Record "Intrastat Jnl. Batch";
    begin
        // [FEATURE] [Purchase] [Item Charge]
        // [SCENARIO] GetEntries for Intrastat should not create line for National Purchase order with Item Charge posted on StartDate of Period
        Initialize;

        // [GIVEN] Purchase Order with empty Country/Region Code on 01.Jan with Item "X"
        LibraryPurchase.CreatePurchHeader(
          PurchaseHeader, PurchaseHeader."Document Type"::Order, CreateVendor(GetCountryRegionCode));
        with PurchaseHeader do begin
            Validate("Posting Date", CalcDate('<+1Y-CM>', WorkDate));
            Validate("Buy-from Country/Region Code", '');
            Modify(true);
        end;
        CreatePurchaseLine(PurchaseHeader, PurchaseLine, PurchaseLine.Type::Item, CreateItem);

        // [GIVEN] Item Charge Purchase Line
        LibraryPatterns.ASSIGNPurchChargeToPurchaseLine(PurchaseHeader, PurchaseLine, 1, LibraryRandom.RandDecInRange(100, 200, 2));

        // [GIVEN] Purchase Order is Received and Invoiced on 01.Jan
        LibraryPurchase.PostPurchaseDocument(PurchaseHeader, true, true);
        LibraryERM.CreateIntrastatJnlTemplateAndBatch(IntrastatJnlBatch, PurchaseHeader."Posting Date");
        LibraryVariableStorage.Enqueue(IntrastatJnlBatch."Journal Template Name");
        LibraryVariableStorage.Enqueue(true); // Show Item Charge entries

        // [WHEN] Run Get Entries on Intrastat Journal with "Show item charge entries" options set to TRUE
        // [THEN] No Intrastat Journal Lines should be created for Item "X"
        OpenAndVerifyIntrastatJournalLine(IntrastatJnlBatch.Name, PurchaseLine."No.", false);

        IntrastatJnlBatch.Delete(true);
    end;

    [Test]
    [HandlerFunctions('IntrastatJnlTemplateListPageHandler,GetItemLedgerEntriesReportHandler')]
    [Scope('OnPrem')]
    procedure NotToShowItemCharges()
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        ItemCharge: Record "Item Charge";
        IntrastatJnlBatch: Record "Intrastat Jnl. Batch";
        NextIntrastatJnlBatch: Record "Intrastat Jnl. Batch";
        DocumentNo: Code[20];
        ItemNo: Code[20];
        InvoicePostingDate: Date;
    begin
        // [FEATURE] [Purchase] [Item Charge]
        // [SCENARIO 377846] No Item Charge entries should be suggested to Intrastat Journal if "Show item charge entries" option is set to FALSE

        Initialize;

        // [GIVEN] Posted Purchase Invoice in "Y" period
        InvoicePostingDate := CalcDate('<' + Format(LibraryRandom.RandInt(5)) + 'Y>', WorkDate);
        DocumentNo := CreateAndPostPurchaseOrder(PurchaseLine, InvoicePostingDate);
        ItemNo := PurchaseLine."No.";

        // [GIVEN] Posted Item Charge in "F" period
        CreatePurchaseHeader(
          PurchaseHeader, PurchaseHeader."Document Type"::Invoice, CalcDate('<1M>', InvoicePostingDate),
          CreateVendor(GetCountryRegionCode));
        LibraryInventory.CreateItemCharge(ItemCharge);
        CreatePurchaseLine(PurchaseHeader, PurchaseLine, PurchaseLine.Type::"Charge (Item)", ItemCharge."No.");
        CreateItemChargeAssignmentForPurchaseCreditMemo(PurchaseLine, DocumentNo);
        LibraryPurchase.PostPurchaseDocument(PurchaseHeader, true, false);

        // [GIVEN] Intrastat Batches for "Y" and "F" period
        LibraryERM.CreateIntrastatJnlTemplateAndBatch(IntrastatJnlBatch, InvoicePostingDate);
        LibraryERM.CreateIntrastatJnlTemplateAndBatch(NextIntrastatJnlBatch, PurchaseHeader."Posting Date");
        LibraryVariableStorage.Enqueue(IntrastatJnlBatch."Journal Template Name");
        LibraryVariableStorage.Enqueue(false); // Show Item Charge entries

        // [WHEN] Suggest Entries to Intrastat Journal "Y" and "F" with "Show item charge entries" options set to FALSE
        // [THEN] Intrastat Journal "Y" contains 1 line for Posted Invoice
        // [THEN] Intrastat Journal "F" does not contain lines for Posted Item Charge
        OpenAndVerifyIntrastatJournalLine(IntrastatJnlBatch.Name, ItemNo, true);
        LibraryVariableStorage.Enqueue(NextIntrastatJnlBatch."Journal Template Name");
        LibraryVariableStorage.Enqueue(false); // Show Item Charge entries
        OpenAndVerifyIntrastatJournalLine(NextIntrastatJnlBatch.Name, ItemNo, false);

        IntrastatJnlBatch.Delete(true);
        NextIntrastatJnlBatch.Delete(true);
    end;

    [Test]
    [Scope('OnPrem')]
    procedure IntrastatJnlBatch_GetStatisticsStartDate()
    var
        IntrastatJnlBatch: Record "Intrastat Jnl. Batch";
    begin
        // [FEATURE] [UT]
        // [SCENARIO 255730] TAB 262 "Intrastat Jnl. Batch".GetStatisticsStartDate() returns statistics period ("YYMM") start date ("01MMYY")
        Initialize;

        // TESTFIELD("Statistics Period")
        IntrastatJnlBatch.Init();
        asserterror IntrastatJnlBatch.GetStatisticsStartDate;
        Assert.ExpectedErrorCode('TestField');
        Assert.ExpectedError(IntrastatJnlBatch.FieldName("Statistics Period"));

        // 01-01-00
        IntrastatJnlBatch."Statistics Period" := '0001';
        Assert.AreEqual(DMY2Date(1, 1, 2000), IntrastatJnlBatch.GetStatisticsStartDate, '');

        // 01-01-18
        IntrastatJnlBatch."Statistics Period" := '1801';
        Assert.AreEqual(DMY2Date(1, 1, 2018), IntrastatJnlBatch.GetStatisticsStartDate, '');

        // 01-12-18
        IntrastatJnlBatch."Statistics Period" := '1812';
        Assert.AreEqual(DMY2Date(1, 12, 2018), IntrastatJnlBatch.GetStatisticsStartDate, '');

        // 01-12-99
        IntrastatJnlBatch."Statistics Period" := '9912';
        Assert.AreEqual(DMY2Date(1, 12, 2099), IntrastatJnlBatch.GetStatisticsStartDate, '');
    end;

    [Test]
    [Scope('OnPrem')]
    procedure IntrastatContact_ChangeType()
    var
        IntrastatSetup: Record "Intrastat Setup";
        Contact: Record Contact;
        Vendor: Record Vendor;
    begin
        // [FEATURE] [Intrastat Setup] [UT]
        // [SCENARIO 255730] "Intrastat Contact No." is blanked when change "Intrastat Contact Type" field value
        Initialize;
        InitIntrastatSetup;

        LibraryMarketing.CreateCompanyContact(Contact);
        LibraryPurchase.CreateVendor(Vendor);
        with IntrastatSetup do begin
            Validate("Intrastat Contact Type", "Intrastat Contact Type"::Contact);
            Validate("Intrastat Contact No.", Contact."No.");
            Validate("Intrastat Contact Type", "Intrastat Contact Type"::Vendor);
            TestField("Intrastat Contact No.", '');
            Validate("Intrastat Contact No.", Vendor."No.");
            Validate("Intrastat Contact Type", "Intrastat Contact Type"::Contact);
            TestField("Intrastat Contact No.", '');
            Validate("Intrastat Contact No.", Contact."No.");
            Validate("Intrastat Contact Type", "Intrastat Contact Type"::" ");
            TestField("Intrastat Contact No.", '');
            Validate("Intrastat Contact Type", "Intrastat Contact Type"::Vendor);
            Validate("Intrastat Contact No.", Vendor."No.");
            Validate("Intrastat Contact Type", "Intrastat Contact Type"::" ");
            TestField("Intrastat Contact No.", '');
        end;
    end;

    [Test]
    [Scope('OnPrem')]
    procedure IntrastatContact_UI_Set()
    var
        IntrastatSetup: Record "Intrastat Setup";
        Contact: Record Contact;
        Vendor: Record Vendor;
        IntrastatContactNo: Code[20];
    begin
        // [FEATURE] [Intrastat Setup] [UT] [UI]
        // [SCENARIO 255730] Set "Intrastat Contact Type" and "Intrastat Contact No." fields via "Intrastat Setup" page
        Initialize;

        // Set "Intrastat Contact Type" = "Contact"
        IntrastatContactNo := LibraryERM.CreateIntrastatContact(IntrastatSetup."Intrastat Contact Type"::Contact);
        SetIntrastatContactViaPage(IntrastatSetup."Intrastat Contact Type"::Contact, IntrastatContactNo);
        VerifyIntrastatContact(IntrastatSetup."Intrastat Contact Type"::Contact, IntrastatContactNo);

        // Set "Intrastat Contact Type" = "Vendor"
        IntrastatContactNo := LibraryERM.CreateIntrastatContact(IntrastatSetup."Intrastat Contact Type"::Vendor);
        SetIntrastatContactViaPage(IntrastatSetup."Intrastat Contact Type"::Vendor, IntrastatContactNo);
        VerifyIntrastatContact(IntrastatSetup."Intrastat Contact Type"::Vendor, IntrastatContactNo);

        // Trying to set "Intrastat Contact Type" = "Contact" with vendor
        Vendor.Get(LibraryPurchase.CreateIntrastatContact(''));
        asserterror SetIntrastatContactViaPage(IntrastatSetup."Intrastat Contact Type"::Contact, Vendor."No.");
        Assert.ExpectedErrorCode('TestValidation');
        Assert.ExpectedError(Contact.TableCaption);

        // Trying to set "Intrastat Contact Type" = "Vendor" with contact
        Contact.Get(LibraryMarketing.CreateIntrastatContact(''));
        asserterror SetIntrastatContactViaPage(IntrastatSetup."Intrastat Contact Type"::Vendor, Contact."No.");
        Assert.ExpectedErrorCode('TestValidation');
        Assert.ExpectedError(Vendor.TableCaption);
    end;

    [Test]
    [HandlerFunctions('ContactList_MPH,VendorList_MPH')]
    [Scope('OnPrem')]
    procedure IntrastatContact_UI_Lookup()
    var
        IntrastatSetup: Record "Intrastat Setup";
        IntrastatContactNo: Code[20];
    begin
        // [FEATURE] [Intrastat Setup] [UT] [UI]
        // [SCENARIO 255730] Lookup "Intrastat Contact No." via "Intrastat Setup" page
        Initialize;

        // Lookup "Intrastat Contact Type" = "" do nothing
        LookupIntrastatContactViaPage(IntrastatSetup."Intrastat Contact Type"::" ");

        // Lookup "Intrastat Contact Type" = "Contact" opens "Contact List" page
        IntrastatContactNo := LibraryERM.CreateIntrastatContact(IntrastatSetup."Intrastat Contact Type"::Contact);
        LibraryVariableStorage.Enqueue(IntrastatContactNo);
        LookupIntrastatContactViaPage(IntrastatSetup."Intrastat Contact Type"::Contact);
        VerifyIntrastatContact(IntrastatSetup."Intrastat Contact Type"::Contact, IntrastatContactNo);

        // Lookup "Intrastat Contact Type" = "Vendor" opens "Vendor List" page
        IntrastatContactNo := LibraryERM.CreateIntrastatContact(IntrastatSetup."Intrastat Contact Type"::Vendor);
        LibraryVariableStorage.Enqueue(IntrastatContactNo);
        LookupIntrastatContactViaPage(IntrastatSetup."Intrastat Contact Type"::Vendor);
        VerifyIntrastatContact(IntrastatSetup."Intrastat Contact Type"::Vendor, IntrastatContactNo);

        LibraryVariableStorage.AssertEmpty;
    end;

    [Test]
    [Scope('OnPrem')]
    procedure IntrastatContact_DeleteContact()
    var
        IntrastatSetup: Record "Intrastat Setup";
        Contact: array[2] of Record Contact;
    begin
        // [FEATURE] [Intrastat Setup] [UT]
        // [SCENARIO 255730] An error has been shown trying to delete contact specified in the Intrastat Setup as an intrastat contact
        Initialize;

        // Empty setup record
        Assert.RecordIsEmpty(IntrastatSetup);
        LibraryMarketing.CreateCompanyContact(Contact[1]);
        Contact[1].Delete(true);

        // Existing setup with other contact
        InitIntrastatSetup;
        LibraryMarketing.CreateCompanyContact(Contact[1]);
        LibraryMarketing.CreateCompanyContact(Contact[2]);
        ValidateIntrastatContact(IntrastatSetup."Intrastat Contact Type"::Contact, Contact[1]."No.");
        Contact[2].Delete(true);

        // Existing setup with the same contact
        asserterror Contact[1].Delete(true);
        Assert.ExpectedErrorCode('Dialog');
        Assert.ExpectedError(StrSubstNo(OnDelIntrastatContactErr, Contact[1]."No."));
    end;

    [Test]
    [Scope('OnPrem')]
    procedure IntrastatContact_DeleteVendor()
    var
        IntrastatSetup: Record "Intrastat Setup";
        Vendor: array[2] of Record Vendor;
    begin
        // [FEATURE] [Intrastat Setup] [UT]
        // [SCENARIO 255730] An error has been shown trying to delete vendor specified in the Intrastat Setup as an intrastat contact
        Initialize;

        // Empty setup record
        Assert.RecordIsEmpty(IntrastatSetup);
        LibraryPurchase.CreateVendor(Vendor[1]);
        Vendor[1].Delete(true);

        // Existing setup with other contact
        InitIntrastatSetup;
        LibraryPurchase.CreateVendor(Vendor[1]);
        LibraryPurchase.CreateVendor(Vendor[2]);
        ValidateIntrastatContact(IntrastatSetup."Intrastat Contact Type"::Vendor, Vendor[1]."No.");
        Vendor[2].Delete(true);

        // Existing setup with the same contact
        asserterror Vendor[1].Delete(true);
        Assert.ExpectedErrorCode('Dialog');
        Assert.ExpectedError(StrSubstNo(OnDelVendorIntrastatContactErr, Vendor[1]."No."));
    end;

    [Test]
    [HandlerFunctions('IntrastatJnlTemplateListPageHandler,GetItemLedgerEntriesReportHandler')]
    [Scope('OnPrem')]
    procedure TestTariffNoNotBlocking()
    var
        IntrastatJnlBatch: Record "Intrastat Jnl. Batch";
        SalesLine: Record "Sales Line";
        Item: Record Item;
        IntrastatJnlLine: Record "Intrastat Jnl. Line";
        IntrastatJournalPage: TestPage "Intrastat Journal";
        InvoiceDate: Date;
    begin
        // [FEATURE] [Intrastat Journal] [Error handling]
        // [SCENARIO 219210] Deliverable 219210:Reporting - Errors and warnings and export in case of blanked "Tariff No."
        // [GIVEN] Posted Sales Order for intrastat without tariff no
        // [GIVEN] Journal Template and Batch
        Initialize;
        InvoiceDate := CalcDate('<-5Y>');
        CreateAndPostSalesOrder(SalesLine, InvoiceDate);
        Item.Get(SalesLine."No.");
        Item.Validate("Tariff No.", '');
        Item.Modify(true);
        LibraryERM.CreateIntrastatJnlTemplateAndBatch(IntrastatJnlBatch, InvoiceDate);
        Commit();

        // [GIVEN] A Intrastat Journal
        OpenIntrastatJournalAndGetEntries(IntrastatJournalPage, IntrastatJnlBatch."Journal Template Name");

        // [WHEN] Running Checklist
        IntrastatJournalPage.ChecklistReport.Invoke;

        // [THEN] You got an error on Tariff no.
        IntrastatJournalPage.ErrorMessagesPart."Field Name".AssertEquals(IntrastatJnlLine.FieldName("Tariff No."));
        IntrastatJournalPage.Close;
    end;

    [Test]
    [HandlerFunctions('IntrastatJnlTemplateListPageHandler,GetItemLedgerEntriesReportHandler,CreateFileMessageHandler')]
    [Scope('OnPrem')]
    procedure TestCreateFileWillCheckErrors()
    var
        IntrastatJnlBatch: Record "Intrastat Jnl. Batch";
        SalesLine: Record "Sales Line";
        IntrastatJnlLine: Record "Intrastat Jnl. Line";
        IntrastatJournalPage: TestPage "Intrastat Journal";
        InvoiceDate: Date;
    begin
        // [FEATURE] [Intrastat Journal] [Error handling]
        // [SCENARIO 219210] Deliverable 219210:Reporting - Errors and warnings and export in case of blanked "Transaction Type"
        // [GIVEN] Posted Sales Order for intrastat
        // [GIVEN] Journal Template and Batch
        Initialize;
        InvoiceDate := CalcDate('<-5Y>');
        CreateAndPostSalesOrder(SalesLine, InvoiceDate);
        LibraryERM.CreateIntrastatJnlTemplateAndBatch(IntrastatJnlBatch, InvoiceDate);
        Commit();

        // [GIVEN] A Intrastat Journal
        OpenIntrastatJournalAndGetEntries(IntrastatJournalPage, IntrastatJnlBatch."Journal Template Name");

        // [WHEN] Running Create File
        IntrastatJournalPage.CreateFile.Invoke;

        // [THEN] CreateFileMessageHandler will verify that you get a message
        // [THEN] You got a error in error part
        IntrastatJournalPage.ErrorMessagesPart."Field Name".AssertEquals(IntrastatJnlLine.FieldName("Transaction Type"));

        IntrastatJournalPage.Close;
    end;

    [MessageHandler]
    [Scope('OnPrem')]
    procedure CreateFileMessageHandler(Message: Text)
    begin
        Assert.AreEqual('One or more errors were found. You must resolve all the errors before you can proceed.', Message, '');
    end;

    [Test]
    [HandlerFunctions('IntrastatJnlTemplateListPageHandler,GetItemLedgerEntriesReportHandler,GreateFileReportHandler')]
    [Scope('OnPrem')]
    procedure E2EErrorHandlingOfIntrastatJournal()
    var
        IntrastatJnlBatch: Record "Intrastat Jnl. Batch";
        SalesLine: Record "Sales Line";
        IntrastatJnlLine: Record "Intrastat Jnl. Line";
        ShipmentMethod: Record "Shipment Method";
        TransactionType: Record "Transaction Type";
        IntrastatJournalPage: TestPage "Intrastat Journal";
        InvoiceDate: Date;
    begin
        // [FEATURE] [Intrastat Journal] [Error handling]
        // [SCENARIO 219210] Deliverable 219210:Reporting - Errors and warnings and export in case of zero "Total Weight"
        // [GIVEN] Posted Sales Order for intrastat
        // [GIVEN] Journal Template and Batch
        Initialize;
        InvoiceDate := CalcDate('<-5Y>');
        CreateAndPostSalesOrder(SalesLine, InvoiceDate);
        LibraryERM.CreateIntrastatJnlTemplateAndBatch(IntrastatJnlBatch, InvoiceDate);
        Commit();

        // [GIVEN] A Intrastat Journal
        OpenIntrastatJournalAndGetEntries(IntrastatJournalPage, IntrastatJnlBatch."Journal Template Name");

        // [WHEN] Running Checklist
        IntrastatJournalPage.ChecklistReport.Invoke;

        // [THEN] You got a error
        IntrastatJournalPage.ErrorMessagesPart."Field Name".AssertEquals(IntrastatJnlLine.FieldName("Transaction Type"));

        // [WHEN] Fixing the error
        TransactionType.FindFirst;
        IntrastatJournalPage."Transaction Type".Value(TransactionType.Code);
        // [WHEN] Running Checklist
        IntrastatJournalPage.ChecklistReport.Invoke;

        // [THEN] You got one more error
        IntrastatJournalPage.ErrorMessagesPart."Field Name".AssertEquals(IntrastatJnlLine.FieldName("Total Weight"));

        // [WHEN] Fixing the error
        IntrastatJournalPage."Total Weight".Value('1');
        // [WHEN] Fixing the error
        ShipmentMethod.FindFirst;
        IntrastatJournalPage."Shpt. Method Code".Value(ShipmentMethod.Code);
        // [WHEN] Running Checklist
        IntrastatJournalPage.ChecklistReport.Invoke;

        // [THEN] You no more errors
        IntrastatJournalPage.ErrorMessagesPart."Field Name".AssertEquals('');

        // [WHEN] Running Create File
        // [THEN] You do not get any errors
        IntrastatJournalPage.CreateFile.Invoke;

        IntrastatJournalPage.Close;
    end;

    [Test]
    [HandlerFunctions('IntrastatJnlTemplateListPageHandler,GetItemLedgerEntriesReportHandler,GreateFileReportHandler')]
    [Scope('OnPrem')]
    procedure E2EErrorHandlingOfIntrastatJournalOnlyReceipt()
    var
        IntrastatJnlBatch: Record "Intrastat Jnl. Batch";
        SalesLine: Record "Sales Line";
        PurchaseLine: Record "Purchase Line";
        ShipmentMethod: Record "Shipment Method";
        TransactionType: Record "Transaction Type";
        TransportMethod: Record "Transport Method";
        IntrastatJournalPage: TestPage "Intrastat Journal";
        InvoiceDate: Date;
    begin
        // [FEATURE] [Intrastat Journal] [Error handling]
        // [SCENARIO 222489] Deliverable 222489:ChecklistReport and CreateFile should filter lines by Intrastat Setup
        // [GIVEN] 1 Posted Purchase Order for intrastat
        // [GIVEN] 1 Posted Sales Order for intrastat
        // [GIVEN] Journal Template and Batch
        Initialize;
        InvoiceDate := CalcDate('<-5Y>');
        InitIntrastatSetup;
        CreateAndPostPurchaseOrder(PurchaseLine, InvoiceDate);
        CreateAndPostSalesOrder(SalesLine, InvoiceDate);
        LibraryERM.CreateIntrastatJnlTemplateAndBatch(IntrastatJnlBatch, InvoiceDate);
        Commit();

        // [GIVEN] A Intrastat Journal
        OpenIntrastatJournalAndGetEntries(IntrastatJournalPage, IntrastatJnlBatch."Journal Template Name");

        // [GIVEN] A Receipt with all values
        TransactionType.FindFirst;
        IntrastatJournalPage."Transaction Type".Value(TransactionType.Code);
        ShipmentMethod.FindFirst;
        IntrastatJournalPage."Shpt. Method Code".Value(ShipmentMethod.Code);
        TransportMethod.FindFirst;
        IntrastatJournalPage."Transport Method".Value(TransportMethod.Code);
        IntrastatJournalPage."Total Weight".Value('1');

        // [WHEN] Running Create File
        // [THEN] You do not get any errors
        IntrastatJournalPage.CreateFile.Invoke;

        IntrastatJournalPage.Close;
    end;

    [RequestPageHandler]
    [Scope('OnPrem')]
    procedure GreateFileReportHandler(var IntrastatMakeDiskTaxAuth: TestRequestPage "Intrastat - Make Disk Tax Auth")
    begin
        IntrastatMakeDiskTaxAuth.Cancel.Invoke;
    end;

    [Test]
    [Scope('OnPrem')]
    procedure ChecklistReportErrorLog()
    var
        IntrastatJnlLine: Record "Intrastat Jnl. Line";
        TestReportPrint: Codeunit "Test Report-Print";
    begin
        // [SCENARIO] User runs Intrastat Checklist report to verify Intrastat Journal Line
        Initialize;
        // [GIVEN] Intrastat Checklist Setup, verify "Document No."
        CreateIntrastatChecklistSetup;
        InitIntrastatSetup;
        // [GIVEN] Intrastat Journal Line with empty "Document No."
        CreateIntrastatJnlLine(IntrastatJnlLine);
        IntrastatJnlLine."Total Weight" := 100;
        IntrastatJnlLine.Modify(true);
        // [WHEN] Run Intrastat Checklist report
        TestReportPrint.PrintIntrastatJnlLine(IntrastatJnlLine);
        // [THEN] Error message is logged for Intrastat Journal Line
        VerifyErrorMessageExists(IntrastatJnlLine);
    end;

    [Test]
    [HandlerFunctions('FieldListModalPageHandler')]
    [Scope('OnPrem')]
    procedure ChecklistSetupUI()
    var
        IntrastatJnlLine: Record "Intrastat Jnl. Line";
        IntrastatChecklistSetupPage: TestPage "Intrastat Checklist Setup";
        IntrastatSetupPage: TestPage "Intrastat Setup";
    begin
        // [SCENARIO] User select fields from Intrastat Journal Line table to verify
        Initialize;
        // [GIVEN] Intrastat Checklist Setup, verify "Document No."
        CreateIntrastatChecklistSetup;
        // [GIVEN] Intrastat Setup page
        IntrastatSetupPage.OpenEdit;
        IntrastatChecklistSetupPage.Trap;
        // [WHEN] Run Intrastat Checklist Setup page
        IntrastatSetupPage.IntrastatChecklistSetup.Invoke;
        IntrastatChecklistSetupPage.First;
        // [THEN] Field "Document No." exists on the page
        Assert.AreEqual(
          IntrastatJnlLine.FieldName("Document No."),
          IntrastatChecklistSetupPage."Field Name".Value,
          'field Document No. should exist on the page');

        // [WHEN] Lookup for other fields and select the first one FieldListModalPageHandler
        IntrastatChecklistSetupPage."Field Name".Lookup;
        // [THEN] Field "Type" should exist on the page
        IntrastatChecklistSetupPage.First;
        Assert.AreEqual(
          IntrastatJnlLine.FieldName(Type),
          IntrastatChecklistSetupPage."Field Name".Value,
          'field Type should exist on the page');
    end;

    [Test]
    [HandlerFunctions('ConfirmHandler,MessageHandler')]
    [Scope('OnPrem')]
    procedure ShptMethodCodeJobJournal()
    var
        IntrastatJnlLine: Record "Intrastat Jnl. Line";
        ShipmentMethod: Record "Shipment Method";
        ItemNo: Code[20];
    begin
        // [FEATURE] [Job]
        // [SCENARIO] User creates and posts job journal and fills intrastat journal
        Initialize;
        // [GIVEN] Shipment Method "SMC"
        ShipmentMethod.FindFirst;
        // [GIVEN] Job Journal Line (posted) with item and "SMC"
        ItemNo := CreateAndPostJobJournalLine(ShipmentMethod.Code);
        // [WHEN] Run Get Item Ledger Entries report
        CreateIntrastatJnlLineAndGetEntries(IntrastatJnlLine, WorkDate, WorkDate);
        // [THEN] "Shpt. Method Code" in the Intrastat Journal Line = "SMC"
        IntrastatJnlLine.SetRange("Item No.", ItemNo);
        IntrastatJnlLine.FindFirst;
        Assert.AreEqual(ShipmentMethod.Code, IntrastatJnlLine."Shpt. Method Code", ShptMethodCodeErr);
    end;

    [Test]
    [HandlerFunctions('GetItemLedgerEntriesReportHandler,MessageHandlerEmpty')]
    [Scope('OnPrem')]
    procedure IntrastatJournalWithItemChargeInvoiceRevoked()
    var
        IntrastatJnlLine: Record "Intrastat Jnl. Line";
        PostingDate: Date;
        DocumentNo: Code[20];
    begin
        // [FEATURE] [Corrective Credit Memo] [Item Charge]
        // [SCENARIO 286107] Item Charge entry posted by Credit Memo must be reported as Receipt in intrastat journal
        Initialize;

        // [GIVEN] Sales Invoice with Item and Item Charge posted on 'X'
        PostingDate := CalcDate('<' + Format(LibraryRandom.RandInt(5)) + 'Y>', WorkDate);
        DocumentNo := CreateAndPostSalesInvoiceWithItemAndItemCharge(PostingDate);
        // [GIVEN] Sales Credit Memo with Item Charge posted on 'Y'='X'+<1M>
        PostingDate := CalcDate('<1M>', PostingDate);
        DocumentNo := CreateAndPostSalesCrMemoForItemCharge(DocumentNo, PostingDate);

        // [WHEN] Get Intrastat Entries to include only Sales Credit Memo
        CreateIntrastatJnlBatchAndGetEntries(IntrastatJnlLine, PostingDate);

        // [THEN] Intrastat line for Item Charge from Sales Credit Memo has type Receipt
        IntrastatJnlLine.SetRange("Document No.", DocumentNo);
        IntrastatJnlLine.FindFirst;
        IntrastatJnlLine.TestField(Type, IntrastatJnlLine.Type::Receipt);
    end;

    [Test]
    [HandlerFunctions('GetItemLedgerEntriesReportHandler')]
    [Scope('OnPrem')]
    procedure IntrastatJournalWithItemChargeInvoiced()
    var
        IntrastatJnlLine: Record "Intrastat Jnl. Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
        ValueEntry: Record "Value Entry";
        PostingDate: Date;
    begin
        // [SCENARIO 286107] Item Charge entry posted by Sales Invoice must be reported as Shipment in intrastat journal
        Initialize;

        // [GIVEN] Item Ledger Entry with Quantity < 0
        PostingDate := CalcDate('<' + Format(LibraryRandom.RandInt(5)) + 'Y>', WorkDate);
        CreateItemLedgerEntry(
          ItemLedgerEntry,
          PostingDate,
          LibraryInventory.CreateItemNo,
          -LibraryRandom.RandInt(100),
          ItemLedgerEntry."Entry Type"::Sale);
        // [GIVEN] Value Entry with "Document Type" != "Sales Credit Memo" and "Item Charge No" posted in <1M>
        PostingDate := CalcDate('<1M>', PostingDate);
        CreateValueEntry(ValueEntry, ItemLedgerEntry, ValueEntry."Document Type"::"Sales Invoice", PostingDate);

        // [WHEN] Get Intrastat Entries on second posting date
        CreateIntrastatJnlBatchAndGetEntries(IntrastatJnlLine, PostingDate);

        // [THEN] Intrastat line for Item Charge from Value Entry has type Shipment
        IntrastatJnlLine.SetRange("Item No.", ItemLedgerEntry."Item No.");
        IntrastatJnlLine.FindFirst;
        IntrastatJnlLine.TestField(Type, IntrastatJnlLine.Type::Shipment);
    end;

    [Test]
    [HandlerFunctions('GetItemLedgerEntriesReportHandler')]
    [Scope('OnPrem')]
    procedure IntrastatJournalWithItemChargeOrderedRevoked()
    var
        IntrastatJnlLine: Record "Intrastat Jnl. Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
        ValueEntry: Record "Value Entry";
        PostingDate: Date;
    begin
        // [SCENARIO 286107] Item Charge entry posted by Purchase Credit Memo must be reported as Shipment in intrastat journal
        Initialize;

        // [GIVEN] Item Ledger Entry with Quantity > 0
        PostingDate := CalcDate('<' + Format(LibraryRandom.RandInt(5)) + 'Y>', WorkDate);
        CreateItemLedgerEntry(
          ItemLedgerEntry,
          PostingDate,
          LibraryInventory.CreateItemNo,
          LibraryRandom.RandInt(100),
          ItemLedgerEntry."Entry Type"::Purchase);
        // [GIVEN] Value Entry with "Document Type" = "Purchase Credit Memo" and "Item Charge No" posted in <1M>
        PostingDate := CalcDate('<1M>', PostingDate);
        CreateValueEntry(ValueEntry, ItemLedgerEntry, ValueEntry."Document Type"::"Purchase Credit Memo", PostingDate);

        // [WHEN] Get Intrastat Entries on second posting date
        CreateIntrastatJnlBatchAndGetEntries(IntrastatJnlLine, PostingDate);

        // [THEN] Intrastat line for Item Charge from Value Entry has type Shipment
        IntrastatJnlLine.SetRange("Item No.", ItemLedgerEntry."Item No.");
        IntrastatJnlLine.FindFirst;
        IntrastatJnlLine.TestField(Type, IntrastatJnlLine.Type::Shipment);
    end;

    [Test]
    [HandlerFunctions('GetItemLedgerEntriesReportHandler')]
    [Scope('OnPrem')]
    procedure IntrastatJournalWithItemChargeOrdered()
    var
        IntrastatJnlLine: Record "Intrastat Jnl. Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
        ValueEntry: Record "Value Entry";
        PostingDate: Date;
    begin
        // [SCENARIO 286107] Item Charge entry posted by Purchase Invoice must be reported as Receipt in intrastat journal
        Initialize;

        // [GIVEN] Item Ledger Entry with Quantity > 0
        PostingDate := CalcDate('<' + Format(LibraryRandom.RandInt(5)) + 'Y>', WorkDate);
        CreateItemLedgerEntry(
          ItemLedgerEntry,
          PostingDate,
          LibraryInventory.CreateItemNo,
          LibraryRandom.RandInt(100),
          ItemLedgerEntry."Entry Type"::Purchase);
        // [GIVEN] Value Entry with "Document Type" != "Purchase Credit Memo" and "Item Charge No" posted in <1M>
        PostingDate := CalcDate('<1M>', PostingDate);
        CreateValueEntry(ValueEntry, ItemLedgerEntry, ValueEntry."Document Type"::"Purchase Invoice", PostingDate);

        // [WHEN] Get Intrastat Entries on second posting date
        CreateIntrastatJnlBatchAndGetEntries(IntrastatJnlLine, PostingDate);

        // [THEN] Intrastat line for Item Charge from Value Entry has type Receipt
        IntrastatJnlLine.SetRange("Item No.", ItemLedgerEntry."Item No.");
        IntrastatJnlLine.FindFirst;
        IntrastatJnlLine.TestField(Type, IntrastatJnlLine.Type::Receipt);
    end;

    [Test]
    [HandlerFunctions('GetItemLedgerEntriesReportHandler')]
    [Scope('OnPrem')]
    procedure IntrastatJournalWithServiceItem()
    var
        IntrastatJnlLine: Record "Intrastat Jnl. Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
        Item: Record Item;
    begin
        // [SCENARIO 295736] Item Ledger Entry with Item Type = Service should not be suggested for Intrastat Journal
        Initialize;

        // [GIVEN] Item Ledger Entry with Service Type Item
        LibraryInventory.CreateServiceTypeItem(Item);
        CreateItemLedgerEntry(
          ItemLedgerEntry,
          WorkDate,
          Item."No.",
          LibraryRandom.RandInt(100),
          ItemLedgerEntry."Entry Type"::Sale);

        // [WHEN] Get Intrastat Entries
        CreateIntrastatJnlBatchAndGetEntries(IntrastatJnlLine, WorkDate);

        // [THEN] There is no Intrastat Line with Item
        IntrastatJnlLine.SetRange("Item No.", ItemLedgerEntry."Item No.");
        Assert.RecordIsEmpty(IntrastatJnlLine);
    end;

    [Test]
    [Scope('OnPrem')]
    procedure IntrastatJournalGetEntriesProcessesLinesWithoutLocation()
    var
        CountryRegion: Record "Country/Region";
        Location: Record Location;
        LocationEU: Record Location;
        TransferLine: Record "Transfer Line";
        IntrastatJnlLine: Record "Intrastat Jnl. Line";
        ItemNo: Code[20];
    begin
        // [SCENARIO 315430] "Get Item Ledger Entries" report generates Intrastat Jnl. Lines when transit Item Ledger Entries have no Location.
        Initialize;

        // [GIVEN] Posted sales order.
        CreateCountryRegion(CountryRegion, true);
        ItemNo := CreateItem;
        CreateFromToLocations(Location, LocationEU, CountryRegion.Code);
        CreateAndPostPurchaseItemJournalLine(Location.Code, ItemNo);
        CreateAndPostSalesOrderWithCountryAndLocation(CountryRegion.Code, Location.Code, ItemNo);
        // [GIVEN] Posted transfer order with blank transit location.
        CreateAndPostTransferOrder(TransferLine, Location.Code, LocationEU.Code, ItemNo);

        // [WHEN] Open "Intrastat Journal" page.
        CreateIntrastatJnlLineAndGetEntries(IntrastatJnlLine, CalcDate('<CM-1M+1D>', WorkDate), CalcDate('<CM>', WorkDate));

        // [THEN] "Intrastat Jnl. Line" is created for posted sales order.
        IntrastatJnlLine.Reset();
        IntrastatJnlLine.SetRange("Item No.", ItemNo);
        Assert.RecordIsNotEmpty(IntrastatJnlLine);
    end;

    local procedure Initialize()
    var
        IntrastatJnlBatch: Record "Intrastat Jnl. Batch";
        IntrastatSetup: Record "Intrastat Setup";
        LibraryERMCountryData: Codeunit "Library - ERM Country Data";
    begin
        LibraryTestInitialize.OnTestInitialize(CODEUNIT::"ERM Intrastat Journal");
        LibraryVariableStorage.Clear;
        IntrastatSetup.DeleteAll();
        if IsInitialized then
            exit;
        LibraryTestInitialize.OnBeforeTestSuiteInitialize(CODEUNIT::"ERM Intrastat Journal");
        UpdateIntrastatCodeInCountryRegion;
        LibraryERMCountryData.CreateVATData;
        LibraryERMCountryData.CreateGeneralPostingSetupData;
        LibraryERMCountryData.UpdateSalesReceivablesSetup;
        LibraryERMCountryData.UpdatePurchasesPayablesSetup;
        LibraryERMCountryData.UpdateGeneralPostingSetup;
        LibraryERM.CreateIntrastatJnlTemplateAndBatch(IntrastatJnlBatch, WorkDate);
        IsInitialized := true;
        Commit();
        LibraryTestInitialize.OnAfterTestSuiteInitialize(CODEUNIT::"ERM Intrastat Journal");
    end;

    local procedure OpenAndVerifyIntrastatJournalLine(BatchName: Code[10]; ItemNo: Code[20]; MustExist: Boolean)
    var
        IntrastatJournal: TestPage "Intrastat Journal";
    begin
        Commit();  // Commit is required to commit the posted entries.

        // Exercise: Get Entries from Intrastat Journal page.
        InvokeGetEntriesOnIntrastatJnl(IntrastatJournal, BatchName);

        // Verify: Verify Intrastat Journal Line with No entires.
        IntrastatJournal.FILTER.SetFilter("Item No.", ItemNo);
        Assert.AreEqual(MustExist, IntrastatJournal.First, LineNotExistErr);
    end;

    local procedure OpenIntrastatJournalAndGetEntries(var IntrastatJournalPage: TestPage "Intrastat Journal"; JournalTemplateName: Code[10])
    begin
        LibraryVariableStorage.Enqueue(JournalTemplateName);
        IntrastatJournalPage.OpenEdit;
        LibraryVariableStorage.Enqueue(false); // Do Not Show Item Charge entries
        IntrastatJournalPage.GetEntries.Invoke;
        IntrastatJournalPage.First;
    end;

    local procedure InitIntrastatSetup()
    var
        IntrastatSetup: Record "Intrastat Setup";
    begin
        with IntrastatSetup do begin
            Init;
            "Report Receipts" := true;
            Insert;
        end;
    end;

    local procedure CreateIntrastatJnlLine(var IntrastatJnlLine: Record "Intrastat Jnl. Line")
    var
        IntrastatJnlTemplate: Record "Intrastat Jnl. Template";
        IntrastatJnlBatch: Record "Intrastat Jnl. Batch";
    begin
        LibraryERM.CreateIntrastatJnlTemplate(IntrastatJnlTemplate);
        CreateAndUpdateIntrastatBatch(
          IntrastatJnlBatch,
          IntrastatJnlTemplate.Name,
          Format(WorkDate, 0, LibraryFiscalYear.GetStatisticsPeriod));
        LibraryERM.CreateIntrastatJnlLine(IntrastatJnlLine, IntrastatJnlBatch."Journal Template Name", IntrastatJnlBatch.Name);
    end;

    local procedure CreateCountryRegion(var CountryRegion: Record "Country/Region"; IsIntrastatRegion: Boolean)
    begin
        LibraryERM.CreateCountryRegion(CountryRegion);
        if IsIntrastatRegion then begin
          CountryRegion.Validate("EU Country/Region Code", CountryRegion.Code);
          CountryRegion.Validate("Intrastat Code", CountryRegion.Code);
          CountryRegion.Modify(true);
        end;
    end;

    local procedure CreateCustomer(): Code[20]
    var
        Customer: Record Customer;
    begin
        LibrarySales.CreateCustomer(Customer);
        Customer.Validate("Country/Region Code", GetCountryRegionCode);
        Customer.Modify(true);
        exit(Customer."No.");
    end;

    local procedure CreateFromToLocations(var LocationFrom: Record Location; var LocationTo: Record Location; CountryRegionCode: Code[10])
    begin
        LibraryWarehouse.CreateLocationWithInventoryPostingSetup(LocationFrom);
        LibraryWarehouse.CreateLocationWithInventoryPostingSetup(LocationTo);
        LocationTo.Validate("Country/Region Code", CountryRegionCode);
        LocationTo.Modify(true);
    end;

    local procedure CreateIntrastatJnlLineAndGetEntries(var IntrastatJnlLine: Record "Intrastat Jnl. Line"; StartDate: Date; EndDate: Date)
    begin
        CreateIntrastatJnlLine(IntrastatJnlLine);
        RunGetItemEntries(IntrastatJnlLine, StartDate, EndDate);
    end;

    local procedure CreateItem(): Code[20]
    var
        Item: Record Item;
    begin
        LibraryInventory.CreateItemWithTariffNo(Item, LibraryUtility.CreateCodeRecord(DATABASE::"Tariff Number"));
        exit(Item."No.");
    end;

    local procedure CreateItemChargeAssignmentForPurchaseCreditMemo(PurchaseLine: Record "Purchase Line"; DocumentNo: Code[20])
    var
        ItemChargeAssignmentPurch: Record "Item Charge Assignment (Purch)";
        PurchRcptLine: Record "Purch. Rcpt. Line";
        ItemChargeAssgntPurch: Codeunit "Item Charge Assgnt. (Purch.)";
    begin
        ItemChargeAssignmentPurch.Init();
        ItemChargeAssignmentPurch.Validate("Document Type", PurchaseLine."Document Type");
        ItemChargeAssignmentPurch.Validate("Document No.", PurchaseLine."Document No.");
        ItemChargeAssignmentPurch.Validate("Document Line No.", PurchaseLine."Line No.");
        ItemChargeAssignmentPurch.Validate("Item Charge No.", PurchaseLine."No.");
        ItemChargeAssignmentPurch.Validate("Unit Cost", PurchaseLine."Direct Unit Cost");
        PurchRcptLine.SetRange("Document No.", DocumentNo);
        PurchRcptLine.FindFirst;
        ItemChargeAssgntPurch.CreateRcptChargeAssgnt(PurchRcptLine, ItemChargeAssignmentPurch);
        UpdatePurchaseItemChargeQtyToAssign(PurchaseLine);
    end;

    local procedure CreateItemChargeAssignmentForSalesCreditMemo(SalesLine: Record "Sales Line"; DocumentNo: Code[20])
    var
        SalesShipmentLine: Record "Sales Shipment Line";
        ItemChargeAssignmentSales: Record "Item Charge Assignment (Sales)";
        ItemChargeAssgntSales: Codeunit "Item Charge Assgnt. (Sales)";
    begin
        ItemChargeAssignmentSales.Init();
        ItemChargeAssignmentSales.Validate("Document Type", SalesLine."Document Type");
        ItemChargeAssignmentSales.Validate("Document No.", SalesLine."Document No.");
        ItemChargeAssignmentSales.Validate("Document Line No.", SalesLine."Line No.");
        ItemChargeAssignmentSales.Validate("Item Charge No.", SalesLine."No.");
        ItemChargeAssignmentSales.Validate("Unit Cost", SalesLine."Unit Price");
        SalesShipmentLine.SetRange("Document No.", DocumentNo);
        SalesShipmentLine.FindFirst;
        ItemChargeAssgntSales.CreateShptChargeAssgnt(SalesShipmentLine, ItemChargeAssignmentSales);
        UpdateSalesItemChargeQtyToAssign(SalesLine);
    end;

    local procedure CreatePurchaseHeader(var PurchaseHeader: Record "Purchase Header"; DocumentType: Option; PostingDate: Date; VendorNo: Code[20])
    begin
        // Create Purchase Order With Random Quantity and Direct Unit Cost.
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, DocumentType, VendorNo);
        with PurchaseHeader do begin
            Validate("Posting Date", PostingDate);
            Modify(true);
        end;
    end;

    local procedure CreatePurchaseLine(var PurchaseHeader: Record "Purchase Header"; var PurchaseLine: Record "Purchase Line"; Type: Option; No: Code[20])
    begin
        // Take Random Values for Purchase Line.
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, Type, No, LibraryRandom.RandDec(10, 2));
        PurchaseLine.Validate("Direct Unit Cost", LibraryRandom.RandDec(100, 2));
        PurchaseLine.Modify(true);
    end;

    local procedure CreateAndPostPurchaseItemJournalLine(LocationCode: Code[10]; ItemNo: Code[20])
    var
        ItemJournalTemplate: Record "Item Journal Template";
        ItemJournalBatch: Record "Item Journal Batch";
        ItemJournalLine: Record "Item Journal Line";
    begin
        LibraryInventory.CreateItemJournalTemplate(ItemJournalTemplate);
        LibraryInventory.CreateItemJournalBatch(ItemJournalBatch, ItemJournalTemplate.Name);
        LibraryInventory.CreateItemJournalLine(
          ItemJournalLine,
          ItemJournalTemplate.Name,
          ItemJournalBatch.Name,
          ItemJournalLine."Entry Type"::Purchase,
          ItemNo,
          LibraryRandom.RandIntInRange(10, 1000));
        ItemJournalLine.Validate("Location Code", LocationCode);
        ItemJournalLine.Modify(true);
        LibraryInventory.PostItemJournalLine(ItemJournalTemplate.Name, ItemJournalBatch.Name);
    end;

    local procedure CreateAndPostPurchaseOrder(var PurchaseLine: Record "Purchase Line"; PostingDate: Date): Code[20]
    var
        PurchaseHeader: Record "Purchase Header";
    begin
        exit(
          CreateAndPostPurchaseDocumentMultiLine(
            PurchaseLine, PurchaseHeader."Document Type"::Order, PostingDate, CreateItem, 1));
    end;

    local procedure CreateAndPostPurchaseDocumentMultiLine(var PurchaseLine: Record "Purchase Line"; DocumentType: Option; PostingDate: Date; ItemNo: Code[20]; NoOfLines: Integer): Code[20]
    var
        PurchaseHeader: Record "Purchase Header";
        i: Integer;
    begin
        CreatePurchaseHeader(PurchaseHeader, DocumentType, PostingDate, CreateVendor(GetCountryRegionCode));
        for i := 1 to NoOfLines do
            CreatePurchaseLine(PurchaseHeader, PurchaseLine, PurchaseLine.Type::Item, ItemNo);

        exit(LibraryPurchase.PostPurchaseDocument(PurchaseHeader, true, false));
    end;

    local procedure CreateAndPostSalesOrder(var SalesLine: Record "Sales Line"; PostingDate: Date): Code[20]
    var
        SalesHeader: Record "Sales Header";
    begin
        exit(
          CreateAndPostSalesDocumentMultiLine(
            SalesLine, SalesHeader."Document Type"::Order, PostingDate, CreateItem, 1));
    end;

    local procedure CreateAndPostSalesOrderWithCountryAndLocation(CountryRegionCode: Code[10]; LocationCode: Code[10]; ItemNo: Code[20])
    var
        Customer: Record Customer;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
    begin
        LibrarySales.CreateCustomerWithLocationCode(Customer, LocationCode);
        Customer.Validate("Country/Region Code", CountryRegionCode);
        Customer.Modify(true);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        SalesHeader.Validate("Location Code", LocationCode);
        SalesHeader.Validate("VAT Country/Region Code", CountryRegionCode);
        SalesHeader.Modify(true);
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, ItemNo, 1);
        LibrarySales.PostSalesDocument(SalesHeader, true, true);
    end;

    local procedure CreateAndPostSalesDocumentMultiLine(var SalesLine: Record "Sales Line"; DocumentType: Option; PostingDate: Date; ItemNo: Code[20]; NoOfSalesLines: Integer): Code[20]
    var
        SalesHeader: Record "Sales Header";
    begin
        CreateSalesDocument(SalesLine, PostingDate, DocumentType, SalesLine.Type::Item, ItemNo, NoOfSalesLines);
        SalesHeader.Get(SalesLine."Document Type", SalesLine."Document No.");

        // Exercise.
        exit(LibrarySales.PostSalesDocument(SalesHeader, true, false));
    end;

    local procedure CreateAndPostTransferOrder(var TransferLine: Record "Transfer Line"; FromLocation: Code[10]; ToLocation: Code[10]; ItemNo: Code[20])
    var
        TransferHeader: Record "Transfer Header";
    begin
        LibraryWarehouse.CreateTransferHeader(TransferHeader, FromLocation, ToLocation,'');
        TransferHeader.Validate("Direct Transfer", true);
        TransferHeader.Modify(true);
        LibraryWarehouse.CreateTransferLine(TransferHeader, TransferLine, ItemNo, 1);
        LibraryWarehouse.PostTransferOrder(TransferHeader, true, true);
    end;

    local procedure CreateShippingAgent(ShippingInternetAddress: Text[250]): Code[10]
    var
        ShippingAgent: Record "Shipping Agent";
    begin
        LibraryInventory.CreateShippingAgent(ShippingAgent);
        ShippingAgent."Internet Address" := ShippingInternetAddress;
        ShippingAgent.Modify();
        exit(ShippingAgent.Code);
    end;

    local procedure UseItemNonZeroNetWeight(var IntrastatJnlLine: Record "Intrastat Jnl. Line"): Decimal
    var
        Item: Record Item;
    begin
        Item.Get(CreateItem);
        IntrastatJnlLine.Validate("Item No.", Item."No.");
        IntrastatJnlLine.Validate(Quantity, LibraryRandom.RandDecInRange(10, 20, 2));
        IntrastatJnlLine.Modify(true);
        exit(Item."Net Weight");
    end;

    local procedure CreateAndUpdateIntrastatBatch(var IntrastatJnlBatch: Record "Intrastat Jnl. Batch"; JournalTemplateName: Code[10]; StatisticsPeriod: Code[10])
    begin
        LibraryERM.CreateIntrastatJnlBatch(IntrastatJnlBatch, JournalTemplateName);
        IntrastatJnlBatch.Validate("Statistics Period", StatisticsPeriod);
        IntrastatJnlBatch.Modify(true);
    end;

    local procedure CreateVendor(CountryRegionCode: Code[10]): Code[20]
    var
        Vendor: Record Vendor;
    begin
        LibraryPurchase.CreateVendor(Vendor);
        Vendor.Validate("Country/Region Code", CountryRegionCode);
        Vendor.Modify(true);
        exit(Vendor."No.");
    end;

    local procedure CreateAndVerifyIntrastatLine(DocumentNo: Code[20]; ItemNo: Code[20]; Quantity: Decimal; IntrastatJnlLineType: Option)
    var
        IntrastatJnlLine: Record "Intrastat Jnl. Line";
    begin
        // Exercise: Run Get Item Entries. Take Starting Date as WORKDATE and Random Ending Date based on WORKDATE.
        CreateIntrastatJnlLineAndGetEntries(
          IntrastatJnlLine, WorkDate, CalcDate('<' + Format(LibraryRandom.RandInt(5)) + 'M>', WorkDate));
        // Verify.
        VerifyIntrastatLine(DocumentNo, ItemNo, IntrastatJnlLineType, GetCountryRegionCode, Quantity);
    end;

    local procedure CreateSalesDocument(var SalesLine: Record "Sales Line"; PostingDate: Date; DocumentType: Option; Type: Option; No: Code[20]; NoOfLines: Integer)
    var
        SalesHeader: Record "Sales Header";
        i: Integer;
    begin
        // Create Sales Order with Random Quantity and Unit Price.
        CreateSalesHeader(SalesHeader, CreateCustomer, PostingDate, DocumentType);
        for i := 1 to NoOfLines do begin
            LibrarySales.CreateSalesLine(SalesLine, SalesHeader, Type, No, LibraryRandom.RandDec(10, 2));
            SalesLine.Validate("Unit Price", LibraryRandom.RandDec(100, 2));
            SalesLine.Modify(true);
        end;
    end;

    local procedure CreateSalesShipmentHeader(var SalesShipmentHeader: Record "Sales Shipment Header"; ShippingInternetAddress: Text[250])
    begin
        SalesShipmentHeader.Init();
        SalesShipmentHeader."Package Tracking No." := LibraryUtility.GenerateGUID;
        SalesShipmentHeader."Shipping Agent Code" := CreateShippingAgent(ShippingInternetAddress);
    end;

    local procedure CreateSalesHeader(var SalesHeader: Record "Sales Header"; CustomerNo: Code[20]; PostingDate: Date; DocumentType: Option)
    begin
        LibrarySales.CreateSalesHeader(SalesHeader, DocumentType, CustomerNo);
        SalesHeader.Validate("Posting Date", PostingDate);
        SalesHeader.Modify(true);
    end;

    local procedure CreateAndPostSalesInvoiceWithItemAndItemCharge(PostingDate: Date): Code[20]
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        SalesLine2: Record "Sales Line";
        LibraryCosting: Codeunit "Library - Costing";
    begin
        CreateSalesHeader(SalesHeader, CreateCustomer, PostingDate, SalesHeader."Document Type"::Invoice);
        LibrarySales.CreateSalesLine(SalesLine2, SalesHeader, SalesLine.Type::Item, '', LibraryRandom.RandDec(10, 2));
        SalesLine2.Validate("Unit Price", LibraryRandom.RandDec(100, 2));
        SalesLine2.Modify(true);
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::"Charge (Item)", '', LibraryRandom.RandDec(10, 2));
        SalesLine.Validate("Unit Price", LibraryRandom.RandDec(100, 2));
        SalesLine.Modify(true);
        LibraryCosting.AssignItemChargeSales(SalesLine, SalesLine2);
        exit(LibrarySales.PostSalesDocument(SalesHeader, false, true));
    end;

    local procedure CreateAndPostSalesCrMemoForItemCharge(PostedSalesInvoiceCode: Code[20]; PostingDate: Date): Code[20]
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        SalesInvoiceHeader: Record "Sales Invoice Header";
        CorrectPostedSalesInvoice: Codeunit "Correct Posted Sales Invoice";
    begin
        SalesInvoiceHeader.Get(PostedSalesInvoiceCode);
        CorrectPostedSalesInvoice.CreateCreditMemoCopyDocument(SalesInvoiceHeader, SalesHeader);
        SalesLine.SetRange("Document Type", SalesLine."Document Type"::"Credit Memo");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        SalesLine.FindFirst;
        SalesLine.Delete(true);
        SalesHeader.Validate("Posting Date", PostingDate);
        SalesHeader.Modify(true);
        exit(LibrarySales.PostSalesDocument(SalesHeader, false, true));
    end;

    local procedure CreateIntrastatJnlBatchAndGetEntries(var IntrastatJnlLine: Record "Intrastat Jnl. Line"; PostingDate: Date)
    var
        IntrastatJnlBatch: Record "Intrastat Jnl. Batch";
        IntrastatJnlTemplate: Record "Intrastat Jnl. Template";
        GetItemLedgerEntries: Report "Get Item Ledger Entries";
    begin
        LibraryERM.CreateIntrastatJnlTemplate(IntrastatJnlTemplate);
        CreateAndUpdateIntrastatBatch(
          IntrastatJnlBatch,
          IntrastatJnlTemplate.Name,
          Format(PostingDate, 0, LibraryFiscalYear.GetStatisticsPeriod));
        LibraryERM.CreateIntrastatJnlLine(IntrastatJnlLine, IntrastatJnlBatch."Journal Template Name", IntrastatJnlBatch.Name);
        LibraryVariableStorage.Enqueue(true);
        GetItemLedgerEntries.SetIntrastatJnlLine(IntrastatJnlLine);
        Commit();
        GetItemLedgerEntries.Run;
    end;

    local procedure CreateItemLedgerEntry(var ItemLedgerEntry: Record "Item Ledger Entry"; PostingDate: Date; ItemNo: Code[20]; Quantity: Decimal; ILEEntryType: Option)
    var
        ItemLedgerEntryNo: Integer;
    begin
        ItemLedgerEntryNo := LibraryUtility.GetNewRecNo(ItemLedgerEntry, ItemLedgerEntry.FieldNo("Entry No."));
        Clear(ItemLedgerEntry);
        ItemLedgerEntry."Entry No." := ItemLedgerEntryNo;
        ItemLedgerEntry."Item No." := ItemNo;
        ItemLedgerEntry."Posting Date" := PostingDate;
        ItemLedgerEntry."Entry Type" := ILEEntryType;
        ItemLedgerEntry.Quantity := Quantity;
        ItemLedgerEntry."Country/Region Code" := GetCountryRegionCode;
        ItemLedgerEntry.Insert();
    end;

    local procedure CreateValueEntry(var ValueEntry: Record "Value Entry"; var ItemLedgerEntry: Record "Item Ledger Entry"; DocumentType: Option; PostingDate: Date)
    var
        ValueEntryNo: Integer;
    begin
        ValueEntryNo := LibraryUtility.GetNewRecNo(ValueEntry, ValueEntry.FieldNo("Entry No."));
        Clear(ValueEntry);
        ValueEntry."Entry No." := ValueEntryNo;
        ValueEntry."Item No." := ItemLedgerEntry."Item No.";
        ValueEntry."Posting Date" := PostingDate;
        ValueEntry."Entry Type" := ValueEntry."Entry Type"::"Direct Cost";
        ValueEntry."Item Ledger Entry Type" := ItemLedgerEntry."Entry Type";
        ValueEntry."Item Ledger Entry No." := ItemLedgerEntry."Entry No.";
        ValueEntry."Item Charge No." := LibraryInventory.CreateItemChargeNo;
        ValueEntry."Document Type" := DocumentType;
        ValueEntry.Insert();
    end;

    local procedure DeleteAndVerifyNoIntrastatLine()
    var
        IntrastatJnlBatch: Record "Intrastat Jnl. Batch";
        IntrastatJnlLine: Record "Intrastat Jnl. Line";
    begin
        // Create and Get Intrastat Journal Lines. Take Random Ending Date based on WORKDATE.
        CreateIntrastatJnlLineAndGetEntries(
          IntrastatJnlLine, WorkDate, CalcDate('<' + Format(LibraryRandom.RandInt(5)) + 'M>', WorkDate));

        // Exercise: Delete all entries from Intrastat Journal Lines.
        IntrastatJnlBatch.Get(IntrastatJnlLine."Journal Template Name", IntrastatJnlLine."Journal Batch Name");
        LibraryERM.ClearIntrastatJnlLines(IntrastatJnlBatch);

        // Verify.
        VerifyNoIntrastatLineExist(IntrastatJnlBatch."Journal Template Name", IntrastatJnlBatch.Name);
    end;

    local procedure GetCountryRegionCode(): Code[10]
    var
        CountryRegion: Record "Country/Region";
        CompanyInformation: Record "Company Information";
    begin
        CompanyInformation.Get();
        CountryRegion.SetFilter(Code, '<>%1', CompanyInformation."Country/Region Code");
        CountryRegion.SetFilter("Intrastat Code", '<>''''');
        CountryRegion.FindFirst;
        exit(CountryRegion.Code);
    end;

    local procedure GetEntriesAndVerifyNoItemLine(DocumentNo: Code[20]; ItemNo: Code[20])
    var
        IntrastatJnlLine: Record "Intrastat Jnl. Line";
    begin
        // Exercise: Run Get Item Entries. Take Starting Date as WORKDATE and Random Ending Date based on WORKDATE.
        CreateIntrastatJnlLineAndGetEntries(
          IntrastatJnlLine, WorkDate, CalcDate('<' + Format(LibraryRandom.RandInt(5)) + 'M>', WorkDate));
        // Verify:
        VerifyNoIntrastatLineForItem(DocumentNo, ItemNo);
    end;

    local procedure RunGetItemEntries(IntrastatJnlLine: Record "Intrastat Jnl. Line"; StartDate: Date; EndDate: Date)
    var
        GetItemLedgerEntries: Report "Get Item Ledger Entries";
    begin
        GetItemLedgerEntries.InitializeRequest(StartDate, EndDate, 0);
        GetItemLedgerEntries.SetIntrastatJnlLine(IntrastatJnlLine);
        GetItemLedgerEntries.UseRequestPage(false);
        GetItemLedgerEntries.Run;
    end;

    local procedure ValidateIntrastatContact(ContactType: Option; ContactNo: Code[20])
    var
        IntrastatSetup: Record "Intrastat Setup";
    begin
        with IntrastatSetup do begin
            Get;
            Validate("Intrastat Contact Type", ContactType);
            Validate("Intrastat Contact No.", ContactNo);
            Modify(true);
        end;
    end;

    local procedure SetIntrastatContactViaPage(ContactType: Option; ContactNo: Code[20])
    var
        IntrastatSetup: TestPage "Intrastat Setup";
    begin
        IntrastatSetup.OpenEdit;
        IntrastatSetup."Intrastat Contact Type".SetValue(ContactType);
        IntrastatSetup."Intrastat Contact No.".SetValue(ContactNo);
        IntrastatSetup.Close;
    end;

    local procedure LookupIntrastatContactViaPage(ContactType: Option)
    var
        IntrastatSetup: TestPage "Intrastat Setup";
    begin
        IntrastatSetup.OpenEdit;
        IntrastatSetup."Intrastat Contact Type".SetValue(ContactType);
        IntrastatSetup."Intrastat Contact No.".Lookup;
        IntrastatSetup.Close;
    end;

    local procedure UpdateIntrastatCodeInCountryRegion()
    var
        CompanyInformation: Record "Company Information";
        CountryRegion: Record "Country/Region";
    begin
        CompanyInformation.Get();
        CompanyInformation."Bank Account No." := '';
        CompanyInformation.Modify();
        CountryRegion.Get(CompanyInformation."Country/Region Code");
        if CountryRegion."Intrastat Code" = '' then begin
            CountryRegion.Validate("Intrastat Code", CountryRegion.Code);
            CountryRegion.Modify(true);
        end;
    end;

    local procedure UpdatePurchaseItemChargeQtyToAssign(PurchaseLine: Record "Purchase Line")
    var
        ItemChargeAssignmentPurch: Record "Item Charge Assignment (Purch)";
    begin
        ItemChargeAssignmentPurch.Get(
          PurchaseLine."Document Type", PurchaseLine."Document No.", PurchaseLine."Line No.", PurchaseLine."Line No.");
        ItemChargeAssignmentPurch.Validate("Qty. to Assign", PurchaseLine.Quantity);
        ItemChargeAssignmentPurch.Modify(true);
    end;

    local procedure UpdateSalesItemChargeQtyToAssign(SalesLine: Record "Sales Line")
    var
        ItemChargeAssignmentSales: Record "Item Charge Assignment (Sales)";
    begin
        ItemChargeAssignmentSales.Get(SalesLine."Document Type", SalesLine."Document No.", SalesLine."Line No.", SalesLine."Line No.");
        ItemChargeAssignmentSales.Validate("Qty. to Assign", SalesLine.Quantity);
        ItemChargeAssignmentSales.Modify(true);
    end;

    local procedure UndoPurchaseReceiptLine(DocumentNo: Code[20]; No: Code[20])
    var
        PurchRcptLine: Record "Purch. Rcpt. Line";
    begin
        PurchRcptLine.SetRange("Document No.", DocumentNo);
        PurchRcptLine.SetRange("No.", No);
        PurchRcptLine.FindFirst;
        LibraryPurchase.UndoPurchaseReceiptLine(PurchRcptLine);
    end;

    local procedure UndoPurchaseReceiptLineByLineNo(DocumentNo: Code[20]; LineNo: Integer)
    var
        PurchRcptLine: Record "Purch. Rcpt. Line";
    begin
        with PurchRcptLine do begin
            SetRange("Document No.", DocumentNo);
            FindSet;
            Next(LineNo - 1);
            SetRecFilter;
        end;
        LibraryPurchase.UndoPurchaseReceiptLine(PurchRcptLine);
    end;

    local procedure UndoReturnShipmentLineByLineNo(DocumentNo: Code[20]; LineNo: Integer)
    var
        ReturnShipmentLine: Record "Return Shipment Line";
    begin
        with ReturnShipmentLine do begin
            SetRange("Document No.", DocumentNo);
            FindSet;
            Next(LineNo - 1);
            SetRecFilter;
        end;
        LibraryPurchase.UndoReturnShipmentLine(ReturnShipmentLine);
    end;

    local procedure UndoSalesShipmentLine(DocumentNo: Code[20]; No: Code[20])
    var
        SalesShipmentLine: Record "Sales Shipment Line";
    begin
        SalesShipmentLine.SetRange("Document No.", DocumentNo);
        SalesShipmentLine.SetRange("No.", No);
        SalesShipmentLine.FindFirst;
        LibrarySales.UndoSalesShipmentLine(SalesShipmentLine);
    end;

    local procedure UndoSalesShipmentLineByLineNo(DocumentNo: Code[20]; LineNo: Integer)
    var
        SalesShipmentLine: Record "Sales Shipment Line";
    begin
        with SalesShipmentLine do begin
            SetRange("Document No.", DocumentNo);
            FindSet;
            Next(LineNo - 1);
            SetRecFilter;
        end;
        LibrarySales.UndoSalesShipmentLine(SalesShipmentLine);
    end;

    local procedure UndoReturnReceiptLineByLineNo(DocumentNo: Code[20]; LineNo: Integer)
    var
        ReturnReceiptLine: Record "Return Receipt Line";
    begin
        with ReturnReceiptLine do begin
            SetRange("Document No.", DocumentNo);
            FindSet;
            Next(LineNo - 1);
            SetRecFilter;
        end;
        LibrarySales.UndoReturnReceiptLine(ReturnReceiptLine);
    end;

    local procedure VerifyIntrastatLine(DocumentNo: Code[20]; ItemNo: Code[20]; Type: Option; CountryRegionCode: Code[10]; Quantity: Decimal)
    var
        IntrastatJnlLine: Record "Intrastat Jnl. Line";
    begin
        IntrastatJnlLine.SetRange("Document No.", DocumentNo);
        IntrastatJnlLine.SetRange("Item No.", ItemNo);
        IntrastatJnlLine.FindFirst;

        Assert.AreEqual(
          Type, IntrastatJnlLine.Type,
          StrSubstNo(ValidationErr, IntrastatJnlLine.FieldCaption(Type), Type, IntrastatJnlLine.TableCaption));

        Assert.AreEqual(
          Quantity, IntrastatJnlLine.Quantity,
          StrSubstNo(ValidationErr, IntrastatJnlLine.FieldCaption(Quantity), Quantity, IntrastatJnlLine.TableCaption));

        Assert.AreEqual(
          CountryRegionCode, IntrastatJnlLine."Country/Region Code", StrSubstNo(ValidationErr,
            IntrastatJnlLine.FieldCaption("Country/Region Code"), CountryRegionCode, IntrastatJnlLine.TableCaption));
    end;

    local procedure VerifyItemLedgerEntry(DocumentType: Option; DocumentNo: Code[20]; CountryRegionCode: Code[10]; Quantity: Decimal)
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        ItemLedgerEntry.SetRange("Document Type", DocumentType);
        ItemLedgerEntry.SetRange("Document No.", DocumentNo);
        ItemLedgerEntry.FindFirst;

        Assert.AreEqual(
          CountryRegionCode, ItemLedgerEntry."Country/Region Code", StrSubstNo(ValidationErr,
            ItemLedgerEntry.FieldCaption("Country/Region Code"), CountryRegionCode, ItemLedgerEntry.TableCaption));

        Assert.AreEqual(
          Quantity, ItemLedgerEntry.Quantity,
          StrSubstNo(ValidationErr, ItemLedgerEntry.FieldCaption(Quantity), Quantity, ItemLedgerEntry.TableCaption));

        Assert.AreEqual(
          0, ItemLedgerEntry."Invoiced Quantity",
          StrSubstNo(ValidationErr, ItemLedgerEntry.FieldCaption("Invoiced Quantity"), 0, ItemLedgerEntry.TableCaption));

        Assert.AreEqual(
          Quantity, ItemLedgerEntry."Remaining Quantity",
          StrSubstNo(ValidationErr, ItemLedgerEntry.FieldCaption("Remaining Quantity"), Quantity, ItemLedgerEntry.TableCaption));
    end;

    local procedure VerifyNoIntrastatLineForItem(DocumentNo: Code[20]; ItemNo: Code[20])
    var
        IntrastatJnlLine: Record "Intrastat Jnl. Line";
    begin
        IntrastatJnlLine.SetRange("Document No.", DocumentNo);
        IntrastatJnlLine.SetRange("Item No.", ItemNo);
        Assert.IsFalse(IntrastatJnlLine.FindFirst, LineNotExistErr);
    end;

    local procedure VerifyNoIntrastatLineExist(JournalTemplateName: Code[10]; JournalBatchName: Code[10])
    var
        IntrastatJnlLine: Record "Intrastat Jnl. Line";
    begin
        IntrastatJnlLine.SetRange("Journal Template Name", JournalTemplateName);
        IntrastatJnlLine.SetRange("Journal Batch Name", JournalBatchName);
        Assert.IsFalse(IntrastatJnlLine.FindFirst, LineNotExistErr);
    end;

    local procedure VerifyNoOfIntrastatLinesForDocumentNo(JournalTemplateName: Code[10]; JournalBatchName: Code[10]; DocumentNo: Code[20]; LineCount: Integer)
    var
        IntrastatJnlLine: Record "Intrastat Jnl. Line";
    begin
        with IntrastatJnlLine do begin
            SetRange("Journal Template Name", JournalTemplateName);
            SetRange("Journal Batch Name", JournalBatchName);
            SetRange("Document No.", DocumentNo);
            Assert.AreEqual(
              LineCount, Count,
              StrSubstNo(LineCountErr, TableCaption));
        end;
    end;

    local procedure VerifyIntrastatContact(ContactType: Option; ContactNo: Code[20])
    var
        IntrastatSetup: Record "Intrastat Setup";
    begin
        with IntrastatSetup do begin
            Get;
            TestField("Intrastat Contact Type", ContactType);
            TestField("Intrastat Contact No.", ContactNo);
        end;
    end;

    local procedure InvokeGetEntriesOnIntrastatJnl(var IntrastatJournal: TestPage "Intrastat Journal"; BatchName: Code[10])
    begin
        IntrastatJournal.OpenEdit;
        IntrastatJournal.CurrentJnlBatchName.SetValue(BatchName);
        IntrastatJournal.GetEntries.Invoke;
    end;

    [ModalPageHandler]
    [Scope('OnPrem')]
    procedure IntrastatJnlTemplateListPageHandler(var IntrastatJnlTemplateList: TestPage "Intrastat Jnl. Template List")
    var
        NameVar: Variant;
    begin
        LibraryVariableStorage.Dequeue(NameVar);
        IntrastatJnlTemplateList.FILTER.SetFilter(Name, NameVar);
        IntrastatJnlTemplateList.OK.Invoke;
    end;

    [RequestPageHandler]
    [Scope('OnPrem')]
    procedure GetItemLedgerEntriesReportHandler(var GetItemLedgerEntries: TestRequestPage "Get Item Ledger Entries")
    begin
        GetItemLedgerEntries.ShowingItemCharges.SetValue(LibraryVariableStorage.DequeueBoolean);
        GetItemLedgerEntries.OK.Invoke;
    end;

    [ConfirmHandler]
    [Scope('OnPrem')]
    procedure UndoDocumentConfirmHandler(Message: Text[1024]; var Reply: Boolean)
    begin
        // Send Reply = TRUE for Confirmation Message.
        Reply := true;
    end;

    [ModalPageHandler]
    [Scope('OnPrem')]
    procedure ContactList_MPH(var ContactList: TestPage "Contact List")
    begin
        ContactList.FILTER.SetFilter("No.", LibraryVariableStorage.DequeueText);
        ContactList.OK.Invoke;
    end;

    [ModalPageHandler]
    [Scope('OnPrem')]
    procedure VendorList_MPH(var VendorLookup: TestPage "Vendor Lookup")
    begin
        VendorLookup.FILTER.SetFilter("No.", LibraryVariableStorage.DequeueText);
        VendorLookup.OK.Invoke;
    end;

    [ModalPageHandler]
    [Scope('OnPrem')]
    procedure FieldListModalPageHandler(var FieldsLookup: TestPage "Fields Lookup")
    begin
        FieldsLookup.First;
        FieldsLookup.OK.Invoke;
    end;

    local procedure CreateIntrastatChecklistSetup()
    var
        IntrastatChecklistSetup: Record "Intrastat Checklist Setup";
        IntrastatJnlLine: Record "Intrastat Jnl. Line";
    begin
        IntrastatChecklistSetup.DeleteAll();

        IntrastatChecklistSetup.Init();
        IntrastatChecklistSetup.Validate("Field No.", IntrastatJnlLine.FieldNo("Document No."));
        IntrastatChecklistSetup.Insert();
    end;

    local procedure CreateAndPostJobJournalLine(ShipmentMethodCode: Code[10]): Code[20]
    var
        CompanyInfo: Record "Company Information";
        CountryRegion: Record "Country/Region";
        Job: Record Job;
        JobJournalLine: Record "Job Journal Line";
        JobTask: Record "Job Task";
        SourceCodeSetup: Record "Source Code Setup";
    begin
        LibraryJob.CreateJob(Job);
        LibraryJob.CreateJobTask(Job, JobTask);
        LibraryJob.CreateJobJournalLineForType(LibraryJob.UsageLineTypeBlank, LibraryJob.ItemType, JobTask, JobJournalLine);
        CompanyInfo.Get();
        CountryRegion.SetFilter(Code, '<>%1', CompanyInfo."Country/Region Code");
        CountryRegion.SetFilter("Intrastat Code", '<>%1', '');
        CountryRegion.FindFirst;
        JobJournalLine.Validate("Country/Region Code", CountryRegion.Code);
        JobJournalLine.Validate("Shpt. Method Code", ShipmentMethodCode);
        SourceCodeSetup.Get();
        JobJournalLine.Validate("Source Code", SourceCodeSetup."Job Journal");
        JobJournalLine.Modify(true);

        LibraryJob.PostJobJournal(JobJournalLine);

        exit(JobJournalLine."No.");
    end;

    local procedure VerifyErrorMessageExists(IntrastatJnlLine: Record "Intrastat Jnl. Line")
    var
        ErrorMessage: Record "Error Message";
    begin
        ErrorMessage.SetRange("Record ID", IntrastatJnlLine.RecordId);
        ErrorMessage.SetRange("Field Number", IntrastatJnlLine.FieldNo("Document No."));
        ErrorMessage.FindFirst;
    end;

    [ConfirmHandler]
    [Scope('OnPrem')]
    procedure ConfirmHandler(Message: Text[1024]; var Reply: Boolean)
    begin
        Reply := true;
    end;

    [MessageHandler]
    [Scope('OnPrem')]
    procedure MessageHandler(Msg: Text[1024])
    begin
        Assert.IsTrue(
          StrPos(Msg, 'The journal lines were successfully posted.') = 1,
          StrSubstNo('Unexpected Message: %1', Msg))
    end;

    [MessageHandler]
    [Scope('OnPrem')]
    procedure MessageHandlerEmpty(Msg: Text[1024])
    begin
    end;
}

