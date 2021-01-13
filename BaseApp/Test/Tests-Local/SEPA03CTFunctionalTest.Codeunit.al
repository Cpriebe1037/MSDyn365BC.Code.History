codeunit 144076 "SEPA.03 CT Functional Test"
{
    Subtype = Test;
    TestPermissions = Disabled;

    trigger OnRun()
    begin
        // [FEATURE] [SEPA] [Credit Transfer]
    end;

    var
        Assert: Codeunit Assert;
        LibraryTestInitialize: Codeunit "Library - Test Initialize";
        LibraryERM: Codeunit "Library - ERM";
        LibraryFRLocalization: Codeunit "Library - FR Localization";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryUtility: Codeunit "Library - Utility";
        LibraryVariableStorage: Codeunit "Library - Variable Storage";
        LibraryRandom: Codeunit "Library - Random";
        StringConversionManagement: Codeunit StringConversionManagement;
        LibraryXMLRead: Codeunit "Library - XML Read";
        LibraryXPathXMLReader: Codeunit "Library - XPath XML Reader";
        isInitialized: Boolean;
        UnexpectedEmptyNodeErr: Label 'Unexpected empty value for node <%1> of subtree <%2>.';
        SEPACTCode: Code[20];
        ElementIsMissingErr: Label 'Element <%1> is missing.';
        FileExportHasErrorsErr: Label 'The file export has one or more errors';

    [Test]
    [HandlerFunctions('PaymentClassHandler,ConfirmHandlerYes')]
    [Scope('OnPrem')]
    procedure LocalDataExported()
    var
        GenJnlLine: Record "Gen. Journal Line";
        GenJournalBatch: Record "Gen. Journal Batch";
        GenJournalTemplate: Record "Gen. Journal Template";
        PaymentHeader: Record "Payment Header";
        PaymentLine: Record "Payment Line";
        PaymentStep: Record "Payment Step";
        PaymentMgt: Codeunit "Payment Management";
    begin
        Initialize;

        CreatePaymentSlip(PaymentHeader, PaymentLine);
        PaymentLine.Amount := -PaymentLine.Amount; // Inject an error
        PaymentLine.Modify;

        PaymentStep.Init;
        PaymentStep."Payment Class" := PaymentHeader."Payment Class";
        PaymentStep."Previous Status" := PaymentHeader."Status No.";
        PaymentStep."Action Type" := PaymentStep."Action Type"::File;
        PaymentStep."Export Type" := PaymentStep."Export Type"::XMLport;
        PaymentStep."Export No." := XMLPORT::"SEPA CT pain.001.001.03";
        PaymentStep.Insert;

        // Must exist a rec with same Document No.
        LibraryERM.FindGenJournalTemplate(GenJournalTemplate);
        LibraryERM.FindGenJournalBatch(GenJournalBatch, GenJournalTemplate.Name);
        LibraryERM.CreateGeneralJnlLine(GenJnlLine, GenJournalTemplate.Name, GenJournalBatch.Name, 0, 0, '', 0);
        GenJnlLine."Document No." := PaymentHeader."No.";
        GenJnlLine.Modify;

        // Excercise
        PaymentStep.SetRange("Action Type", PaymentStep."Action Type"::File);
        asserterror PaymentMgt.ProcessPaymentSteps(PaymentHeader, PaymentStep);

        // Verify. Error message is about File Export Errors
        Assert.ExpectedError(FileExportHasErrorsErr);
    end;

    [Test]
    [HandlerFunctions('PaymentClassHandler')]
    [Scope('OnPrem')]
    procedure XmlFileDeclarationAndVersion()
    var
        PaymentHeader: Record "Payment Header";
        PaymentLine: Record "Payment Line";
    begin
        InitializeTestDataAndExportSEPAFile(PaymentHeader, PaymentLine);
        VerifyXmlFileDeclarationAndVersion;
    end;

    [Test]
    [HandlerFunctions('PaymentClassHandler')]
    [Scope('OnPrem')]
    procedure XmlFileGroupHeader()
    var
        PaymentHeader: Record "Payment Header";
        PaymentLine: Record "Payment Line";
    begin
        InitializeTestDataAndExportSEPAFile(PaymentHeader, PaymentLine);
        VerifyGroupHeader(PaymentLine);
    end;

    [Test]
    [HandlerFunctions('PaymentClassHandler')]
    [Scope('OnPrem')]
    procedure XmlFileInitiatingParty()
    var
        PaymentHeader: Record "Payment Header";
        PaymentLine: Record "Payment Line";
    begin
        InitializeTestDataAndExportSEPAFile(PaymentHeader, PaymentLine);
        VerifyInitiatingParty;
    end;

    [Test]
    [HandlerFunctions('PaymentClassHandler')]
    [Scope('OnPrem')]
    procedure XmlFilePaymentInformationHeader()
    var
        PaymentHeader: Record "Payment Header";
        PaymentLine: Record "Payment Line";
    begin
        InitializeTestDataAndExportSEPAFile(PaymentHeader, PaymentLine);
        VerifyPaymentInformationHeader(PaymentLine);
    end;

    [Test]
    [HandlerFunctions('PaymentClassHandler')]
    [Scope('OnPrem')]
    procedure XmlFileDebitor()
    var
        PaymentHeader: Record "Payment Header";
        PaymentLine: Record "Payment Line";
    begin
        InitializeTestDataAndExportSEPAFile(PaymentHeader, PaymentLine);
        VerifyDebitor(PaymentHeader);
    end;

    [Test]
    [HandlerFunctions('PaymentClassHandler')]
    [Scope('OnPrem')]
    procedure XmlFileCreditor()
    var
        PaymentHeader: Record "Payment Header";
        PaymentLine: Record "Payment Line";
    begin
        InitializeTestDataAndExportSEPAFile(PaymentHeader, PaymentLine);
        VerifyCreditor(PaymentLine);
    end;

    [Test]
    [HandlerFunctions('PaymentClassHandler')]
    [Scope('OnPrem')]
    procedure XmlFileCreditorPreserveNonLatinChars()
    var
        PaymentHeader: Record "Payment Header";
        PaymentLine: Record "Payment Line";
    begin
        SetPreserveNonLatinCharacters(true);
        InitializeTestDataAndExportSEPAFile(PaymentHeader, PaymentLine);
        VerifyCreditor(PaymentLine);
    end;

    [Test]
    [HandlerFunctions('PaymentClassHandler')]
    [Scope('OnPrem')]
    procedure ExportSEPACTSvcLvlCd()
    var
        PaymentHeader: Record "Payment Header";
        PaymentLine: Record "Payment Line";
        ExportedFilePath: Text;
    begin
        // [SCENARIO 344720] SEPA Export File contains element PmtInf/PmtTpInf/SvcLvl/Cd with value 'SEPA'.
        Initialize;

        // [GIVEN] Payment Slip.
        CreatePaymentSlip(PaymentHeader, PaymentLine);

        // [WHEN] Export SEPA CT file.
        ExportedFilePath := ExportSEPAFile(PaymentHeader);

        // [THEN] SEPA CT file contains element PmtInf/PmtTpInf/SvcLvl/Cd with value 'SEPA'.
        LibraryXPathXMLReader.Initialize(ExportedFilePath, GetISO20022V03NameSpace);
        LibraryXPathXMLReader.VerifyNodeValueByXPath('//PmtInf/PmtTpInf/SvcLvl/Cd', 'SEPA');
    end;

    local procedure Initialize()
    begin
        LibraryTestInitialize.OnTestInitialize(CODEUNIT::"SEPA.03 CT Functional Test");
        if isInitialized then
            exit;
        LibraryTestInitialize.OnBeforeTestSuiteInitialize(CODEUNIT::"SEPA.03 CT Functional Test");

        SEPACTCode := FindSEPACTPaymentFormat;
        AllowSEPAOnCompanyCountryCode;
        isInitialized := true;
        LibraryTestInitialize.OnAfterTestSuiteInitialize(CODEUNIT::"SEPA.03 CT Functional Test");
    end;

    [TransactionModel(TransactionModel::None)]
    local procedure AllowSEPAOnCountryCode(CountryRegionCode: Code[10])
    var
        CountryRegion: Record "Country/Region";
    begin
        with CountryRegion do begin
            Get(CountryRegionCode);
            if not "SEPA Allowed" then begin
                Validate("SEPA Allowed", true);
                Modify(true);
            end;
        end;
    end;

    local procedure AllowSEPAOnCompanyCountryCode()
    var
        CompanyInfo: Record "Company Information";
    begin
        CompanyInfo.Get;
        AllowSEPAOnCountryCode(CompanyInfo."Country/Region Code");
    end;

    local procedure CreateSEPABankAccount(var BankAccount: Record "Bank Account")
    begin
        LibraryERM.CreateBankAccount(BankAccount);
        with BankAccount do begin
            Validate(Balance, LibraryRandom.RandIntInRange(100000, 1000000));
            Validate("Bank Account No.", LibraryUtility.GenerateRandomCode(FieldNo("Bank Account No."), DATABASE::"Bank Account"));
            Validate("Country/Region Code", GetASEPACountryCode);
            Validate(IBAN, 'ES7620770024003102575766');
            Validate("Payment Export Format", SEPACTCode);
            Validate("Credit Transfer Msg. Nos.", LibraryERM.CreateNoSeriesCode);
            Validate("SWIFT Code", 'BSCHESMM');
            Modify(true);
        end;
    end;

    local procedure CreatePaymentClass(): Code[20]
    var
        NoSeries: Record "No. Series";
        PaymentClass: Record "Payment Class";
        PaymentStatus: Record "Payment Status";
    begin
        NoSeries.FindFirst;
        LibraryFRLocalization.CreatePaymentClass(PaymentClass);
        with PaymentClass do begin
            Validate(Name, '');
            Validate("Header No. Series", NoSeries.Code);
            Validate(Enable, true);
            Validate(Suggestions, Suggestions::Vendor);
            Validate("SEPA Transfer Type", "SEPA Transfer Type"::"Credit Transfer");
            Modify(true);
            LibraryFRLocalization.CreatePaymentStatus(PaymentStatus, Code);
        end;
        exit(PaymentClass.Code);
    end;

    local procedure CreatePaymentSlip(var PaymentHeader: Record "Payment Header"; var PaymentLine: Record "Payment Line")
    var
        BankAccount: Record "Bank Account";
        PaymentClassCode: Code[30];
    begin
        PaymentClassCode := CreatePaymentClass;
        LibraryVariableStorage.Enqueue(PaymentClassCode);

        LibraryFRLocalization.CreatePaymentHeader(PaymentHeader);
        with PaymentHeader do begin
            Validate("Account Type", "Account Type"::"Bank Account");
            CreateSEPABankAccount(BankAccount);
            Validate("Account No.", BankAccount."No.");
            Validate("Bank Country/Region Code", BankAccount."Country/Region Code");
            Validate(IBAN, 'CH6309000000250097798');
            Validate("SWIFT Code", 'INGBNL2A');
            Modify(true);
        end;

        LibraryFRLocalization.CreatePaymentLine(PaymentLine, PaymentHeader."No.");
        with PaymentLine do begin
            Validate("Account Type", "Account Type"::Vendor);
            Validate("Account No.", CreateVendor);
            Validate(Amount, LibraryRandom.RandDecInRange(1, 1000, 1));
            Validate("Due Date", CalcDate('1D', "Due Date"));
            Modify(true);
        end;
    end;

    local procedure CreateVendor(): Code[20]
    var
        BankAccount: Record "Bank Account";
        PostCode: Record "Post Code";
        Vendor: Record Vendor;
        VendorBankAccount: Record "Vendor Bank Account";
    begin
        CreateSEPABankAccount(BankAccount);

        LibraryPurchase.CreateVendor(Vendor);
        with VendorBankAccount do begin
            Init;
            Validate(Code, BankAccount.Name);
            Validate("Vendor No.", Vendor."No.");
            Insert(true);
        end;

        with VendorBankAccount do begin
            Validate(Name, BankAccount.Name);
            Validate("Bank Account No.", BankAccount.Name);
            Validate("Country/Region Code", BankAccount."Country/Region Code");
            Validate(IBAN, BankAccount.IBAN);
            Validate("SWIFT Code", BankAccount."SWIFT Code");
            Modify(true);
        end;

        with Vendor do begin
            Validate("Country/Region Code", BankAccount."Country/Region Code");
            Validate("Preferred Bank Account Code", BankAccount."No.");
            Validate(Address, '´Š¢sterbrogade ´Š¢´Š¢'); // for testing non latin characters
            PostCode.SetRange("Country/Region Code", "Country/Region Code");
            PostCode.FindFirst;
            Validate("Post Code", PostCode.Code);
            Validate(City, PostCode.City);
            Modify(true);
        end;

        exit(Vendor."No.");
    end;

    local procedure ExportSEPAFile(var PaymentHeader: Record "Payment Header") ExportedFilePath: Text
    var
        GenJnlLine: Record "Gen. Journal Line";
        OutStr: OutStream;
        File: File;
    begin
        GenJnlLine.SetRange("Journal Template Name", '');
        GenJnlLine.SetRange("Journal Batch Name", '');
        GenJnlLine.SetRange("Document No.", PaymentHeader."No.");
        ExportedFilePath := TemporaryPath + LibraryUtility.GenerateGUID + '.xml';
        File.Create(ExportedFilePath);
        File.CreateOutStream(OutStr);
        XMLPORT.Export(XMLPORT::"SEPA CT pain.001.001.03", OutStr, GenJnlLine);
        File.Close;
    end;

    local procedure FindSEPACTPaymentFormat(): Code[20]
    var
        BankExportImportSetup: Record "Bank Export/Import Setup";
    begin
        BankExportImportSetup.SetRange("Processing XMLport ID", XMLPORT::"SEPA CT pain.001.001.03");
        BankExportImportSetup.FindFirst;
        exit(BankExportImportSetup.Code);
    end;

    local procedure GetASEPACountryCode(): Code[10]
    var
        CountryRegion: Record "Country/Region";
        PostCode: Record "Post Code";
    begin
        PostCode.Next(LibraryRandom.RandInt(PostCode.Count));
        CountryRegion.Get(PostCode."Country/Region Code");
        AllowSEPAOnCountryCode(CountryRegion.Code);
        exit(CountryRegion.Code);
    end;

    local procedure GetPreserveNonLatinCharacters(): Boolean
    var
        BankExportImportSetup: Record "Bank Export/Import Setup";
    begin
        BankExportImportSetup.Get(SEPACTCode);
        exit(BankExportImportSetup."Preserve Non-Latin Characters");
    end;

    local procedure GetISO20022V03NameSpace(): Text
    begin
        exit('urn:iso:std:iso:20022:tech:xsd:pain.001.001.03');
    end;

    local procedure InitializeTestDataAndExportSEPAFile(var PaymentHeader: Record "Payment Header"; var PaymentLine: Record "Payment Line")
    var
        ExportedFilePath: Text;
    begin
        Initialize;
        CreatePaymentSlip(PaymentHeader, PaymentLine);
        ExportedFilePath := ExportSEPAFile(PaymentHeader);
        LibraryXMLRead.Initialize(ExportedFilePath);
    end;

    [ModalPageHandler]
    [Scope('OnPrem')]
    procedure PaymentClassHandler(var PaymentClassList: TestPage "Payment Class List")
    var
        PaymentClassCode: Variant;
    begin
        LibraryVariableStorage.Dequeue(PaymentClassCode);
        PaymentClassList.GotoKey(PaymentClassCode);
        PaymentClassList.OK.Invoke;
    end;

    local procedure SetPreserveNonLatinCharacters(Preserve: Boolean)
    var
        BankExportImportSetup: Record "Bank Export/Import Setup";
    begin
        with BankExportImportSetup do begin
            Get(SEPACTCode);
            if not ("Preserve Non-Latin Characters" = Preserve) then begin
                Validate("Preserve Non-Latin Characters", Preserve);
                Modify(true);
            end;
        end;
    end;

    local procedure VerifyDebitor(PaymentHeader: Record "Payment Header")
    var
        BankAccount: Record "Bank Account";
        CompanyInformation: Record "Company Information";
    begin
        CompanyInformation.Get;
        VerifyCompanyNameAndPostalAddress(CompanyInformation, 'Dbtr');

        BankAccount.Get(PaymentHeader."Account No.");
        LibraryXMLRead.VerifyNodeValueInSubtree('Dbtr', 'BICOrBEI', BankAccount."SWIFT Code");
        LibraryXMLRead.VerifyNodeValueInSubtree('DbtrAcct', 'IBAN', BankAccount.IBAN);
        LibraryXMLRead.VerifyNodeValueInSubtree('DbtrAgt', 'BIC', BankAccount."SWIFT Code");
    end;

    local procedure VerifyCreditor(PaymentLine: Record "Payment Line")
    var
        Vendor: Record Vendor;
    begin
        Vendor.Get(PaymentLine."Account No.");
        VerifyNameAndPostalAddress(
          'Cdtr', Vendor.Name, Vendor.Address, Vendor."Post Code", Vendor.City, Vendor."Country/Region Code");
        LibraryXMLRead.VerifyNodeValueInSubtree('CdtrAcct', 'IBAN', PaymentLine.IBAN);
        LibraryXMLRead.VerifyNodeValueInSubtree('CdtTrfTxInf', 'InstdAmt', PaymentLine.Amount);
        LibraryXMLRead.VerifyAttributeValueInSubtree('CdtTrfTxInf', 'InstdAmt', 'Ccy', 'EUR');
        asserterror LibraryXMLRead.VerifyNodeValue('Ustrd', '');
        Assert.ExpectedError(StrSubstNo(ElementIsMissingErr, 'Ustrd'));
    end;

    local procedure VerifyGroupHeader(PaymentLine: Record "Payment Line")
    begin
        // Mandatory/required elements
        VerifyNodeExistsAndNotEmpty('GrpHdr', 'MsgId');
        VerifyNodeExistsAndNotEmpty('GrpHdr', 'CreDtTm');
        LibraryXMLRead.VerifyNodeValueInSubtree('GrpHdr', 'NbOfTxs', '1');
        LibraryXMLRead.VerifyNodeValueInSubtree('GrpHdr', 'CtrlSum', PaymentLine.Amount);
    end;

    local procedure VerifyInitiatingParty()
    var
        CompanyInformation: Record "Company Information";
    begin
        CompanyInformation.Get;
        LibraryXMLRead.VerifyNodeValueInSubtree('InitgPty', 'Nm', CompanyInformation.Name);
        LibraryXMLRead.VerifyNodeValueInSubtree('InitgPty', 'Id', CompanyInformation."VAT Registration No.");
        // TFSID: 327225 Removal of 'PstlAdr' tag since the scheme has been changed
        LibraryXMLRead.VerifyNodeAbsenceInSubtree('InitgPty', 'PstlAdr');
    end;

    local procedure VerifyPaymentInformationHeader(PaymentLine: Record "Payment Line")
    begin
        // Mandatory elements
        VerifyNodeExistsAndNotEmpty('PmtInf', 'PmtInfId');
        LibraryXMLRead.VerifyNodeValueInSubtree('PmtInf', 'PmtMtd', 'TRF'); // Hardcoded to 'TRF' by the FR SEPA standard

        // Optional element
        LibraryXMLRead.VerifyNodeValueInSubtree('PmtInf', 'BtchBookg', 'false');

        // Mandatory element
        LibraryXMLRead.VerifyNodeValueInSubtree('PmtInf', 'ReqdExctnDt', PaymentLine."Posting Date");

        LibraryXMLRead.VerifyNodeValueInSubtree('PmtInf', 'ChrgBr', 'SLEV'); // Hardcoded by FR SEPA standard
    end;

    local procedure VerifyCompanyNameAndPostalAddress(CompanyInformation: Record "Company Information"; SubtreeRootNodeName: Text)
    begin
        VerifyNameAndPostalAddress(
          SubtreeRootNodeName, CompanyInformation.Name, CompanyInformation.Address,
          CompanyInformation."Post Code", CompanyInformation.City, CompanyInformation."Country/Region Code");
    end;

    local procedure VerifyNameAndPostalAddress(SubtreeRootNodeName: Text; Name: Text; Address: Text; PostCode: Text; City: Text; CountryRegionCode: Text)
    begin
        VerifyNodeValue(SubtreeRootNodeName, 'Nm', Name);
        VerifyNodeValue(SubtreeRootNodeName, 'StrtNm', Address);
        VerifyNodeValue(SubtreeRootNodeName, 'PstCd', PostCode);
        VerifyNodeValue(SubtreeRootNodeName, 'TwnNm', City);
        VerifyNodeValue(SubtreeRootNodeName, 'Ctry', CountryRegionCode);
    end;

    local procedure VerifyNodeExistsAndNotEmpty(SubtreeRootName: Text; NodeName: Text)
    begin
        Assert.AreNotEqual(
          '', LibraryXMLRead.GetNodeValueInSubtree(SubtreeRootName, NodeName), StrSubstNo(UnexpectedEmptyNodeErr, NodeName, SubtreeRootName));
    end;

    local procedure VerifyNodeValue(SubtreeRootNodeName: Text; NodeName: Text; ExpectedValue: Text)
    begin
        if not GetPreserveNonLatinCharacters then
            ExpectedValue := StringConversionManagement.WindowsToASCII(ExpectedValue);
        LibraryXMLRead.VerifyNodeValueInSubtree(SubtreeRootNodeName, NodeName, ExpectedValue);
    end;

    local procedure VerifyXmlFileDeclarationAndVersion()
    begin
        LibraryXMLRead.VerifyXMLDeclaration('1.0', 'UTF-8', 'no');
        LibraryXMLRead.VerifyAttributeValue('Document', 'xmlns', 'urn:iso:std:iso:20022:tech:xsd:pain.001.001.03');
    end;

    [ConfirmHandler]
    [Scope('OnPrem')]
    procedure ConfirmHandlerYes(Question: Text; var Reply: Boolean)
    begin
        Reply := true;
    end;
}

