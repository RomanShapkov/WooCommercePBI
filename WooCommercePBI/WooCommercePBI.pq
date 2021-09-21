// This file contains your Data Connector logic
section WooCommercePBI;

[DataSource.Kind="WooCommercePBI", Publish="WooCommercePBI.Publish"]
shared WooCommercePBI.NavTableNested = () as table =>
    let

        NavTable = (tb as table) => Table.ToNavigationTable(tb, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf"),
        table_header = {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},

        lv1 = #table(
            table_header,
            {
                {"fGetProducts", "fGetProducts", WooCommercePBI.getProducts, "function", "function", "true"},
                {"fGetOrders", "fGetOrders", WooCommercePBI.getOrders, "function", "function", "true"},
                {"fGetCustomers", "fGetCustomers", WooCommercePBI.getCustomers, "function", "function", "true"},
                {"fGetReportsSales", "fGetReportsSales", WooCommercePBI.getReportsSales, "function", "function", "true"},
                {"fGetCategories", "fGetCategories", WooCommercePBI.getCategories, "function", "function", "true"}
            }   
        )
    in
        NavTable(lv1);


WooCommercePBI.getProducts = (
        domen_url as text,
        after as date,
        before as date,
        page as number,
        per_page as number,
        pagination as logical
    ) =>
    let
        endpoint = Uri.Combine(domen_url, "/wp-json/wc/v3/products"),
        params = [
            #"after" = Date.ToText(after, "yyyy-MM-ddT00:00:00"),
            #"before" = Date.ToText(before, "yyyy-MM-ddT00:00:00"),
            #"page" = Text.From(page),
            #"per_page" = Text.From(per_page),
            #"order" = "asc",
            #"orderby" = "id",
            #"status" = "any"
            ],
        data = getData(endpoint, params, pagination),
        tb = toTable(data)
    in 
        tb;

WooCommercePBI.getOrders = (
        domen_url as text,
        after as date,
        before as date,
        page as number,
        per_page as number,
        pagination as logical
    ) =>
    let
        endpoint = Uri.Combine(domen_url, "/wp-json/wc/v3/orders"),
        params = [
            #"after" = Date.ToText(after, "yyyy-MM-ddT00:00:00"),
            #"before" = Date.ToText(before, "yyyy-MM-ddT00:00:00"),
            #"page" = Text.From(page),
            #"per_page" = Text.From(per_page),
            #"order" = "asc",
            #"orderby" = "id",
            #"status" = "any"
            ],
        data = getData(endpoint, params, pagination),
        tb = toTable(data)
    in 
        tb;


WooCommercePBI.getCustomers = (
        domen_url as text,
        page as number,
        per_page as number,
        pagination as logical
    ) =>
    let
        endpoint = Uri.Combine(domen_url, "/wp-json/wc/v3/customers"),
        params = [
            #"page" = Text.From(page),
            #"per_page" = Text.From(per_page),
            #"order" = "asc",
            #"orderby" = "id"
            ],
        data = getData(endpoint, params, pagination),
        tb = toTable(data)
    in 
        tb;

WooCommercePBI.getCategories = (
        domen_url as text,
        page as number,
        per_page as number,
        pagination as logical
    ) =>
    let
        endpoint = Uri.Combine(domen_url, "/wp-json/wc/v3/products/categories"),
        params = [
            #"page" = Text.From(page),
            #"per_page" = Text.From(per_page),
            #"order" = "asc",
            #"orderby" = "id"
            ],
        data = getData(endpoint, params, pagination),
        tb = toTable(data)
    in 
        tb;

WooCommercePBI.getReportsSales = (
        domen_url as text,
        date_min as date,
        date_max as date
    ) =>
    let
        endpoint = Uri.Combine(domen_url, "/wp-json/wc/v3/reports/sales"),
        params = [
            #"date_min" = Date.ToText(date_min, "yyyy-MM-dd"),
            #"date_max" = Date.ToText(date_max, "yyyy-MM-dd")
            ],
        data = getData(endpoint, params, false),
        tb = toTable(data)
    in 
        tb;


getData = (endpoint as text, params as record, pagination as logical) =>
    let
        func = (optional page as number) => 
            let
                a = if page is null then Record.FieldOrDefault(params, "page", 1) else Text.From(page),
                b = Record.RemoveFields(params, "page", MissingField.Ignore),
                c = Record.AddField(b, "page", Text.From(a)),
                d = Json.Document( Web.Contents(endpoint, [Query = c]))
            in
                d,
        allPageJson =
            let 
                startpos = Number.From(Record.FieldOrDefault(params, "page", 1)),
                allPage = 
                    List.Combine(
                        List.Generate( 
                            ()=> [ x = startpos , y = func(x)],
                            each not(List.IsEmpty([y])),
                            each [ x=[x] + 1, y = func(x) ],
                            each [y]
                        )
                    )
            in
                allPage,
        result = if pagination then allPageJson else func()
    in 
        result;


// Data Source Kind description
WooCommercePBI = [
    TestConnection = (dataSourcePath) => {"WooCommercePBI.NavTableNested"},
    Authentication = [
        UsernamePassword = [
            UsernameLabel = "consumer_key",
            PasswordLabel = "consumer_secret"
            ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
WooCommercePBI.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = WooCommercePBI.Icons,
    SourceTypeImage = WooCommercePBI.Icons
];

WooCommercePBI.Icons = [
    Icon16 = { Extension.Contents("WooCommercePBI16.png"), Extension.Contents("WooCommercePBI20.png"), Extension.Contents("WooCommercePBI24.png"), Extension.Contents("WooCommercePBI32.png") },
    Icon32 = { Extension.Contents("WooCommercePBI32.png"), Extension.Contents("WooCommercePBI40.png"), Extension.Contents("WooCommercePBI48.png"), Extension.Contents("WooCommercePBI64.png") }
];


Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            Preview.DelayColumn = itemNameColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;


toTable = (lstrec as list, optional index as number) as table =>
    let
        fieldnames = 
            let
                toprows = if index is null then lstrec else List.FirstN(lstrec, index),
                listfields = List.Transform(toprows, Record.FieldNames),
                namesdistinct = List.Union(listfields)
            in
                namesdistinct,
        tbl = Table.FromRecords(lstrec, fieldnames, MissingField.UseNull)
    in
        tbl;