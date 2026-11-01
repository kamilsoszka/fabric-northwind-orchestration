[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Append"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
shared DefaultDestination = Fabric.Warehouse([CreateNavigationProperties = false]){[workspaceId = "c7cd7ada-b82b-42df-a430-002cfaf90309"]}[Data]{[warehouseId = "3e3109c2-2af9-4380-99de-2a4c9c42692f"]}[Data];
[BindToDefaultDestination = true]
shared Categories = let
  Source = OData.Feed("https://services.odata.org/v4/northwind/northwind.svc/", null, [Implementation = "2.0"]),
  #"Navigation 1" = Source{[Name = "Categories", Signature = "table"]}[Data],
  #"Choose columns" = Table.SelectColumns(#"Navigation 1", {"CategoryID", "CategoryName", "Description"})
in
  #"Choose columns";
[BindToDefaultDestination = true]
shared Customers = let
  Source = OData.Feed("https://services.odata.org/v4/northwind/northwind.svc/", null, [Implementation = "2.0"]),
  #"Navigation 1" = Source{[Name = "Customers", Signature = "table"]}[Data],
  #"Choose columns" = Table.SelectColumns(#"Navigation 1", {"CustomerID", "CompanyName", "ContactName", "ContactTitle", "Address", "City", "Region", "PostalCode", "Country", "Phone", "Fax"})
in
  #"Choose columns";
[BindToDefaultDestination = true]
shared Employees = let
  Source = OData.Feed("https://services.odata.org/v4/northwind/northwind.svc/", null, [Implementation = "2.0"]),
  #"Navigation 1" = Source{[Name = "Employees", Signature = "table"]}[Data],
  #"Choose columns" = Table.SelectColumns(#"Navigation 1", {"EmployeeID", "LastName", "FirstName", "Title", "TitleOfCourtesy", "BirthDate", "HireDate", "Address", "City", "Region", "PostalCode", "Country", "HomePhone", "Extension", "Photo", "Notes", "ReportsTo", "PhotoPath"})
in
  #"Choose columns";
[BindToDefaultDestination = true]
shared Order_Details = let
  Source = OData.Feed("https://services.odata.org/v4/northwind/northwind.svc/", null, [Implementation = "2.0"]),
  #"Navigation 1" = Source{[Name = "Order_Details", Signature = "table"]}[Data],
  #"Choose columns" = Table.SelectColumns(#"Navigation 1", {"OrderID", "ProductID", "UnitPrice", "Quantity", "Discount"})
in
  #"Choose columns";
[BindToDefaultDestination = true]
shared Orders = let
  Source = OData.Feed("https://services.odata.org/v4/northwind/northwind.svc/", null, [Implementation = "2.0"]),
  #"Navigation 1" = Source{[Name = "Orders", Signature = "table"]}[Data],
  #"Choose columns" = Table.SelectColumns(#"Navigation 1", {"OrderID", "CustomerID", "EmployeeID", "OrderDate", "RequiredDate", "ShippedDate", "ShipVia", "Freight", "ShipName", "ShipAddress", "ShipCity", "ShipRegion", "ShipPostalCode", "ShipCountry"})
in
  #"Choose columns";
[BindToDefaultDestination = true]
shared Products = let
  Source = OData.Feed("https://services.odata.org/v4/northwind/northwind.svc/", null, [Implementation = "2.0"]),
  #"Navigation 1" = Source{[Name = "Products", Signature = "table"]}[Data],
  #"Choose columns" = Table.SelectColumns(#"Navigation 1", {"ProductID", "ProductName", "SupplierID", "CategoryID", "QuantityPerUnit", "UnitPrice", "UnitsInStock", "UnitsOnOrder", "ReorderLevel", "Discontinued"})
in
  #"Choose columns";
[BindToDefaultDestination = true]
shared Shippers = let
  Source = OData.Feed("https://services.odata.org/v4/northwind/northwind.svc/", null, [Implementation = "2.0"]),
  #"Navigation 1" = Source{[Name = "Shippers", Signature = "table"]}[Data],
  #"Choose columns" = Table.SelectColumns(#"Navigation 1", {"ShipperID", "CompanyName", "Phone"})
in
  #"Choose columns";
[BindToDefaultDestination = true]
shared Suppliers = let
  Source = OData.Feed("https://services.odata.org/v4/northwind/northwind.svc/", null, [Implementation = "2.0"]),
  #"Navigation 1" = Source{[Name = "Suppliers", Signature = "table"]}[Data],
  #"Choose columns" = Table.SelectColumns(#"Navigation 1", {"SupplierID", "CompanyName", "ContactName", "ContactTitle", "Address", "City", "Region", "PostalCode", "Country", "Phone", "Fax", "HomePage"})
in
  #"Choose columns";
