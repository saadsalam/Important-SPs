IF EXISTS (select * from sysobjects where name =
	'spGenerateFreightVerifyVehicleVisibilityData' and type = 'P')

DROP PROC spGenerateFreightVerifyVehicleVisibilityData
GO

CREATE PROC spGenerateFreightVerifyVehicleVisibilityData (@CustomerID int, @CreatedBy varchar(20))
AS
BEGIN
	set nocount on

	DECLARE
	@ErrorID				int,
	--FreightVerifyExportVehicleVisibility table variables
	@FreightVerifyExportVehicleVisibilityID	int,
	@BatchID				int,
	--@VehicleID				int,
	--@LegsID				int,
	@CarrierID				varchar(20),
	@CarrierSCAC				varchar(4),
	@Customer				varchar(10),
	@ShipmentIdentification			varchar(60),
	@ProNumber				varchar(10),
	@TelematicProvider			varchar(20),
	--@TrackingAssetID			varchar(20),
	@ShipUnitsTotalQuantity			int,
	@TrailerType				varchar(10),
	--@TrailerNumber			varchar(10),
	@TeamDrivers				varchar(10),
	@Hazmat					varchar(10),
	@ShipFromStopSequence			int,
	@ShipFromStopType			varchar(10),
	@ShipFromStopRole			varchar(10),
	@ShipFromEarlyArrival			datetime,
	@ShipFromLateArrival			datetime,
	@ShipFromStopDuration			varchar(10),
	@ShipFromLocationIDQualilfier		varchar(10),
	@ShipFromLocationID			varchar(10),
	@ShipFromName				varchar(100),
	@ShipFromAddressLine1			varchar(50),
	@ShipFromAddressLine2			varchar(50),
	@ShipFromCity				varchar(30),
	@ShipFromState				varchar(2),
	@ShipFromPostalCode			varchar(14),
	@ShipFromCountry			varchar(10),
	@ShipToStopSequence			int,
	@ShipToStopType				varchar(10),
	@ShipToStopRole				varchar(10),
	@ShipToEarlyArrival			datetime,
	@ShipToLateArrival			datetime,
	@ShipToStopDuration			varchar(10),
	@ShipToLocationIDQualilfier		varchar(10),
	@ShipToLocationID			varchar(10),
	@ShipToName				varchar(100),
	@ShipToAddressLine1			varchar(50),
	@ShipToAddressLine2			varchar(50),
	@ShipToCity				varchar(30),
	@ShipToState				varchar(2),
	@ShipToPostalCode			varchar(14),
	@ShipToCountry				varchar(10),
	@ShipToQuantity				int,
	@StopReferenceQualifier			varchar(20),
	@StopReferenceDescription		varchar(20),
	@StopReferenceValue			varchar(20),
	--@VIN					varchar(17),
	@ShipmentReferenceQualifier		varchar(20),
	@ShipmentReferenceDescription		varchar(20),
	--@ShipmentReferenceValue		varchar(20),
	@Latitude				varchar(20),
	@Longitude				varchar(20),
	--@EventDate				datetime,
	@Event					varchar(2),
	@EventReason				varchar(2),
	@ExportedInd				int,
	--@ExportedDate				datetime,
	--@ExportedBy				varchar(20),
	@RecordStatus				varchar(255),
	@CreationDate				datetime,
	--@UpdatedDate				datetime,
	--@UpdatedBy				varchar(20),

	--processing variables
	@FreightVerifyStartDate			datetime,
	@GMCustomerID				int,
	@FVLocationCodeType			varchar(30),
	@LoopCounter				int,
	@Status					varchar(100),
	@ReturnCode				int,
	@ReturnMessage				varchar(100)

	/************************************************************************
	*	spGenerateFreightVerifyVehicleVisibilityData			*
	*									*
	*	Description							*
	*	-----------							*
	*	This procedure generates the vehicle visibility export data for	*
	*	vehicles that are EnRoute or Delivered.				*
	*									*
	*	Change History							*
	*	--------------							*
	*	Date       Init's Description					*
	*	---------- ------ ----------------------------------------	*
	*	05/21/2019 CMK    Initial version				*
	*	09/12/2019 CMK    Changes to CP and LO code to not require 	*
	*			  FreightVerifyShipmentID to be populated in	*
	*			  order to generate records those records at	*
	*			  the same time as the initial XB records	*
	*									*
	************************************************************************/
	
	SELECT @ErrorID = 0
	
	--get the gm customer id from the setting table
	SELECT @GMCustomerID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'GMCustomerID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting GMCustomerID'
		GOTO Error_Encountered2
	END
	IF @GMCustomerID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'GMCustomerID Not Found'
		GOTO Error_Encountered2
	END
	
	--get the next batch id from the setting table
	SELECT @BatchID = CONVERT(int,ValueDescription)
	FROM SettingTable
	WHERE ValueKey = 'NextFreightVerifyVehicleVisibilityExportBatchID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting BatchID'
		GOTO Error_Encountered2
	END
	IF @BatchID IS NULL
	BEGIN
		SELECT @ErrorID = 100001
		SELECT @Status = 'BatchID Not Found'
		GOTO Error_Encountered2
	END
	
	--get the Freight Verify CarrierID from the setting table
	SELECT TOP 1 @CarrierID = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'FreightVerifyCarrierID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting FreightVerifyCarrierID'
		GOTO Error_Encountered2
	END
	IF @BatchID IS NULL
	BEGIN
		SELECT @ErrorID = 100002
		SELECT @Status = 'FreightVerifyCarrierID Not Found'
		GOTO Error_Encountered2
	END
	
	--get the company scac from the setting table
	SELECT TOP 1 @CarrierSCAC = ValueDescription
	FROM SettingTable
	WHERE ValueKey = 'CompanySCACCode'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting CompanySCACCode'
		GOTO Error_Encountered2
	END
	IF @BatchID IS NULL
	BEGIN
		SELECT @ErrorID = 100003
		SELECT @Status = 'CompanySCACCode Not Found'
		GOTO Error_Encountered2
	END
	
	--get the Customer and Freight Verify Start Date
	SELECT @Customer = Code,
	@FreightVerifyStartDate = Value2
	FROM Code
	WHERE CodeType = 'FVCustomerCode'
	AND Value1 = CONVERT(varchar(10),@CustomerID)
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Getting Freight Verify Start Date'
		GOTO Error_Encountered2
	END
	IF @Customer IS NULL
	BEGIN
		SELECT @ErrorID = 100005
		SELECT @Status = 'Freight Verify Customer Not Found'
		GOTO Error_Encountered2
	END
	IF @FreightVerifyStartDate IS NULL
	BEGIN
		SELECT @ErrorID = 100005
		SELECT @Status = 'Freight Verify Start Date Not Found'
		GOTO Error_Encountered2
	END
		
	SELECT @FVLocationCodeType = 'FV'+@Customer+'LocationCode'
	--BEGIN TRAN
	
	--set the default values
		
	SELECT @LoopCounter = 0
	
	--these defaults are for all types
	SELECT @ExportedInd = 0
	SELECT @RecordStatus = 'Export Pending'
	SELECT @CreationDate = CURRENT_TIMESTAMP
	
	--process the Asset Assigned records
	
	--Asset Assigned defaults
	SELECT @ShipmentIdentification = ''
	SELECT @TelematicProvider = 'self'
	SELECT @TrailerType = 'auto'
	SELECT @TeamDrivers = 'false'
	SELECT @Hazmat = 'false'
	SELECT @ShipFromStopSequence = 1
	SELECT @ShipFromStopType = 'load'
	SELECT @ShipFromStopRole = 'ship_from'
	SELECT @ShipFromEarlyArrival = DATEADD(hour,-3, CURRENT_TIMESTAMP)
	SELECT @ShipFromLateArrival = DATEADD(day,2, CURRENT_TIMESTAMP)
	SELECT @ShipFromStopDuration = '1H30M'
	SELECT @ShipFromLocationIDQualilfier = 'customer'
	SELECT @ShipToStopSequence = 2
	SELECT @ShipToStopType = 'unload'
	SELECT @ShipToStopRole = 'ship_to'
	SELECT @ShipToEarlyArrival = CURRENT_TIMESTAMP
	SELECT @ShipToLateArrival = DATEADD(day,4, CURRENT_TIMESTAMP)
	SELECT @ShipToStopDuration = '1H30M'
	SELECT @ShipToLocationIDQualilfier = 'customer'
	SELECT @StopReferenceQualifier = 'bol'
	SELECT @StopReferenceDescription = 'bill of lading'
	SELECT @ShipmentReferenceQualifier = 'bol'
	SELECT @ShipmentReferenceDescription = 'bill of lading'
	SELECT @Latitude = NULL
	SELECT @Longitude = NULL
	SELECT @Event = 'XB'
	SELECT @EventReason = 'NS'
	
	INSERT INTO FreightVerifyExportVehicleVisibility (BatchID, VehicleID, LegsID, CarrierID, CarrierSCAC, Customer, ShipmentIdentification,
		ProNumber, TelematicProvider, TrackingAssetID, ShipUnitsTotalQuantity, TrailerType, TrailerNumber, TeamDrivers, Hazmat,
		ShipFromStopSequence, ShipFromStopType, ShipFromStopRole, ShipFromEarlyArrival, ShipFromLateArrival, ShipFromStopDuration,
		ShipFromLocationIDQualilfier, ShipFromLocationID, ShipFromName, ShipFromAddressLine1, ShipFromAddressLine2, ShipFromCity,
		ShipFromState, ShipFromPostalCode, ShipFromCountry, ShipToStopSequence, ShipToStopType, ShipToStopRole, ShipToEarlyArrival,
		ShipToLateArrival, ShipToStopDuration, ShipToLocationIDQualilfier, ShipToLocationID, ShipToName, ShipToAddressLine1,
		ShipToAddressLine2, ShipToCity, ShipToState, ShipToPostalCode, ShipToCountry, ShipToQuantity, StopReferenceQualifier,
		StopReferenceDescription, StopReferenceValue, VIN, ShipmentReferenceQualifier, ShipmentReferenceDescription,
		ShipmentReferenceValue, Latitude, Longitude, EventDate, Event, EventReason, ExportedInd, RecordStatus, CreationDate,
		CreatedBy, CustomerID)
		SELECT @BatchID,
		V.VehicleID,
		L.LegsID,
		@CarrierID,
		@CarrierSCAC,
		@Customer,
		@ShipmentIdentification,
		L2.LoadNumber,	--ProNumber
		@TelematicProvider,
		T.TruckNumber,	--TrackingAssetID
		(SELECT COUNT(*) FROM Vehicle V2
			LEFT JOIN Legs L5 ON V2.VehicleID = L5.VehicleID
			LEFT JOIN Location L6 ON L5.DropoffLocationID = L6.LocationID 
			WHERE L5.LoadID = L.LoadID
			AND V2.CustomerID = V.CustomerID
			AND L5.PickupLocationID = L.PickupLocationID
			AND L5.DropoffLocationID = L.DropoffLocationID
			AND CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = @FVLocationCodeType AND Value1 = CONVERT(varchar(10),L4.LocationID))
			WHEN V.CustomerID = @GMCustomerID AND DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) = 8 THEN REPLACE(L4.CustomerLocationCode,'-','')
			WHEN V.CustomerID = @GMCustomerID AND DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) = 5 THEN LEFT(V.CustomerIdentification,2)+L4.CustomerLocationCode
			WHEN V.CustomerID <> @GMCustomerID AND DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) <> 0 THEN L4.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END
			= CASE WHEN L6.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = @FVLocationCodeType AND Value1 = CONVERT(varchar(10),L6.LocationID))
			WHEN V2.CustomerID = @GMCustomerID AND DATALENGTH(ISNULL(L6.CustomerLocationCode,'')) = 8 THEN REPLACE(L6.CustomerLocationCode,'-','')
			WHEN V2.CustomerID = @GMCustomerID AND DATALENGTH(ISNULL(L6.CustomerLocationCode,'')) = 5 THEN LEFT(V2.CustomerIdentification,2)+L6.CustomerLocationCode
			WHEN V2.CustomerID <> @GMCustomerID AND DATALENGTH(ISNULL(L6.CustomerLocationCode,'')) <> 0 THEN L6.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L6.SPLCCode,'')) > 0 THEN L6.SPLCCode END
			), --ShipUnitsTotalQuantity
		@TrailerType,
		T.TruckNumber,	--TrailerNumber
		@TeamDrivers,
		@Hazmat,
		@ShipFromStopSequence,
		@ShipFromStopType,
		@ShipFromStopRole,
		@ShipFromEarlyArrival,
		@ShipFromLateArrival,
		@ShipFromStopDuration,
		@ShipFromLocationIDQualilfier,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = @FVLocationCodeType AND Value1 = CONVERT(varchar(10),L3.LocationID))
			WHEN V.CustomerID = @GMCustomerID AND DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) = 8 THEN REPLACE(L3.CustomerLocationCode,'-','')
			WHEN V.CustomerID = @GMCustomerID AND DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) = 5 THEN LEFT(V.CustomerIdentification,2)+L3.CustomerLocationCode
			WHEN V.CustomerID <> @GMCustomerID AND DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) <> 0 THEN L3.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END ShipFromLocationID,
		L3.LocationName, 	--ShipFromName
		ISNULL(L3.AddressLine1,'TBD'),	--ShipFromAddressLine1
		ISNULL(L3.AddressLine2,''),	--ShipFromAddressLine2
		L3.City,	--ShipFromCity
		L3.State,	--ShipFromState
		L3.Zip,		--ShipFromPostalCode
		CASE WHEN L3.Country = 'U.S.A.' THEN 'US' WHEN L3.Country = 'Canada' THEN 'CA' ELSE '' END,	--ShipFromCountry
		@ShipToStopSequence,
		@ShipToStopType,
		@ShipToStopRole,
		@ShipToEarlyArrival,
		@ShipToLateArrival,
		@ShipToStopDuration,
		@ShipToLocationIDQualilfier,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = @FVLocationCodeType AND Value1 = CONVERT(varchar(10),L4.LocationID))
			WHEN V.CustomerID = @GMCustomerID AND DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) = 8 THEN REPLACE(L4.CustomerLocationCode,'-','')
			WHEN V.CustomerID = @GMCustomerID AND DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) = 5 THEN LEFT(V.CustomerIdentification,2)+L4.CustomerLocationCode
			WHEN V.CustomerID <> @GMCustomerID AND DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) <> 0 THEN L4.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END ShipToLocationID,
		L4.LocationName, 	--ShipToName
		ISNULL(L4.AddressLine1,'TBD'),	--ShipToAddressLine1
		ISNULL(L4.AddressLine2,''),	--ShipToAddressLine2
		L4.City,	--ShipToCity
		L4.State,	--ShipToState
		L4.Zip,		--ShipToPostalCode
		CASE WHEN L4.Country = 'U.S.A.' THEN 'US' WHEN L4.Country = 'Canada' THEN 'CA' ELSE '' END,	--ShipToCountry
		(SELECT COUNT(*) FROM Vehicle V2
			LEFT JOIN Legs L5 ON V2.VehicleID = L5.VehicleID
			LEFT JOIN Location L6 ON L5.DropoffLocationID = L6.LocationID 
			WHERE L5.LoadID = L.LoadID
			AND V2.CustomerID = V.CustomerID
			AND L5.PickupLocationID = L.PickupLocationID
			AND L5.DropoffLocationID = L.DropoffLocationID
			AND CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = @FVLocationCodeType AND Value1 = CONVERT(varchar(10),L4.LocationID))
			WHEN V.CustomerID = @GMCustomerID AND DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) = 8 THEN REPLACE(L4.CustomerLocationCode,'-','')
			WHEN V.CustomerID = @GMCustomerID AND DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) = 5 THEN LEFT(V.CustomerIdentification,2)+L4.CustomerLocationCode
			WHEN V.CustomerID <> @GMCustomerID AND DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) <> 0 THEN L4.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END
			= CASE WHEN L6.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = @FVLocationCodeType AND Value1 = CONVERT(varchar(10),L6.LocationID))
			WHEN V2.CustomerID = @GMCustomerID AND DATALENGTH(ISNULL(L6.CustomerLocationCode,'')) = 8 THEN REPLACE(L6.CustomerLocationCode,'-','')
			WHEN V2.CustomerID = @GMCustomerID AND DATALENGTH(ISNULL(L6.CustomerLocationCode,'')) = 5 THEN LEFT(V2.CustomerIdentification,2)+L6.CustomerLocationCode
			WHEN V2.CustomerID <> @GMCustomerID AND DATALENGTH(ISNULL(L6.CustomerLocationCode,'')) <> 0 THEN L6.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L6.SPLCCode,'')) > 0 THEN L6.SPLCCode END), --ShipToQuantity
		@StopReferenceQualifier,
		@StopReferenceDescription,
		L2.LoadNumber,	--StopReferenceValue
		V.VIN,
		@ShipmentReferenceQualifier,
		@ShipmentReferenceDescription,
		L2.LoadNumber,	--ShipmentReferenceValue
		@Latitude,
		@Longitude,
		CASE WHEN L2.LoadStatus = 'Scheduled & Assigned' THEN ISNULL(L2.ScheduledPickupDate, CURRENT_TIMESTAMP)
			WHEN L2.LoadStatus IN ('EnRoute','Delivered') AND L2.ScheduledPickupDate IS NOT NULL THEN L2.ScheduledPickupDate
			ELSE DATEADD(hour,-1,L.PickupDate) END, --EventDate
		@Event,
		@EventReason,
		@ExportedInd,
		@RecordStatus,
		@CreationDate,
		@CreatedBy,
		V.CustomerID
	FROM Vehicle V
	LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
	LEFT JOIN Loads L2 ON L.LoadID = L2.LoadsID
	LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
	LEFT JOIN Location L4 ON V.DropoffLocationID = L4.LocationID
	LEFT JOIN Driver D ON L2.DriverID = D.DriverID
	LEFT JOIN Truck T ON D.CurrentTruckID = T.TruckID
	WHERE V.CustomerID = @CustomerID
	AND ISNULL(L2.ScheduledPickupDate,L.PickupDate) >= @FreightVerifyStartDate
	AND L.LoadID IS NOT NULL
	AND L2.LoadStatus IN ('EnRoute','Delivered') --'Scheduled & Assigned', 
	AND V.VehicleID NOT IN (SELECT FV.VehicleID FROM FreightVerifyExportVehicleVisibility FV WHERE FV.Event = 'XB')
	--AND (CONVERT(varchar(10),V.PickupLocationID) IN (SELECT C.Value1 FROM Code C WHERE C.CodeType = 'FV'+@Customer+'LocationCode')
	--OR L3.ParentRecordTable <> 'Common')
	AND L3.City IS NOT NULL
	AND L3.State IS NOT NULL
	AND L3.Zip IS NOT NULL
	AND L3.Country IS NOT NULL
	AND L4.City IS NOT NULL
	AND L4.State IS NOT NULL
	AND L4.Zip IS NOT NULL
	AND L4.Country IS NOT NULL
	AND DATALENGTH(ISNULL(V.CustomerIdentification,'')) >= 2
	ORDER BY L2.LoadNumber, ShipFromLocationID, ShipToLocationID
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error creating Asset Assigned records'
		GOTO Error_Encountered
	END
	
	--end of process the Asset Assigned records
	
	--process the Pickup Complete records
		
	--Asset Assigned defaults
	SELECT @TelematicProvider = 'self'
	SELECT @ShipUnitsTotalQuantity = NULL
	SELECT @TrailerType = ''
	SELECT @TeamDrivers = ''
	SELECT @Hazmat = ''
	SELECT @ShipFromStopSequence = 1
	SELECT @ShipFromStopType = ''
	SELECT @ShipFromStopRole = ''
	SELECT @ShipFromEarlyArrival = NULL
	SELECT @ShipFromLateArrival = NULL
	SELECT @ShipFromStopDuration = ''
	SELECT @ShipFromStopType = ''
	SELECT @ShipFromStopRole = ''
	SELECT @ShipFromEarlyArrival = NULL
	SELECT @ShipFromLateArrival = NULL
	SELECT @ShipFromStopDuration = ''
	SELECT @ShipFromLocationIDQualilfier = 'customer'
	SELECT @ShipToStopSequence = NULL
	SELECT @ShipToStopType = ''
	SELECT @ShipToStopRole = ''
	SELECT @ShipToEarlyArrival = NULL
	SELECT @ShipToLateArrival = NULL
	SELECT @ShipToStopDuration = ''
	SELECT @ShipToLocationIDQualilfier = ''
	SELECT @ShipToName = ''
	SELECT @ShipToAddressLine1 = ''
	SELECT @ShipToAddressLine2 = ''
	SELECT @ShipToCity = ''
	SELECT @ShipToState = ''
	SELECT @ShipToPostalCode = ''
	SELECT @ShipToCountry = ''
	SELECT @ShipToQuantity = NULL
	SELECT @StopReferenceQualifier = ''
	SELECT @StopReferenceDescription = ''
	SELECT @StopReferenceValue = ''
	SELECT @StopReferenceQualifier = ''
	SELECT @StopReferenceDescription = ''
	SELECT @ShipmentReferenceQualifier = 'bol'
	SELECT @ShipmentReferenceDescription = 'bill of lading'
	SELECT @Latitude = NULL
	SELECT @Longitude = NULL
	SELECT @Event = 'CP'
	SELECT @EventReason = 'NS'

	INSERT INTO FreightVerifyExportVehicleVisibility (BatchID, VehicleID, LegsID, CarrierID, CarrierSCAC, Customer, ShipmentIdentification,
		ProNumber, TelematicProvider, TrackingAssetID, ShipUnitsTotalQuantity, TrailerType, TrailerNumber, TeamDrivers, Hazmat,
		ShipFromStopSequence, ShipFromStopType, ShipFromStopRole, ShipFromEarlyArrival, ShipFromLateArrival, ShipFromStopDuration,
		ShipFromLocationIDQualilfier, ShipFromLocationID, ShipFromName, ShipFromAddressLine1, ShipFromAddressLine2, ShipFromCity,
		ShipFromState, ShipFromPostalCode, ShipFromCountry, ShipToStopSequence, ShipToStopType, ShipToStopRole, ShipToEarlyArrival,
		ShipToLateArrival, ShipToStopDuration, ShipToLocationIDQualilfier, ShipToLocationID, ShipToName, ShipToAddressLine1,
		ShipToAddressLine2, ShipToCity, ShipToState, ShipToPostalCode, ShipToCountry, ShipToQuantity, StopReferenceQualifier,
		StopReferenceDescription, StopReferenceValue, VIN, ShipmentReferenceQualifier, ShipmentReferenceDescription,
		ShipmentReferenceValue, Latitude, Longitude, EventDate, Event, EventReason, ExportedInd, RecordStatus, CreationDate,
		CreatedBy, CustomerID)
		SELECT @BatchID,
		V.VehicleID,
		L.LegsID,
		@CarrierID,
		@CarrierSCAC,
		@Customer,
		L.FreightVerifyShipmentID,	--ShipmentIdentification
		L2.LoadNumber,	--ProNumber,
		@TelematicProvider,
		T.TruckNumber,	--TrackingAssetID
		@ShipUnitsTotalQuantity,
		@TrailerType,
		T.TruckNumber,	--TrailerNumber
		@TeamDrivers,
		@Hazmat,
		@ShipFromStopSequence,
		@ShipFromStopType,
		@ShipFromStopRole,
		@ShipFromEarlyArrival,
		@ShipFromLateArrival,
		@ShipFromStopDuration,
		@ShipFromLocationIDQualilfier,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = @FVLocationCodeType AND Value1 = CONVERT(varchar(10),L3.LocationID))
			WHEN V.CustomerID = @GMCustomerID AND DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) = 8 THEN REPLACE(L3.CustomerLocationCode,'-','')
			WHEN V.CustomerID = @GMCustomerID AND DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) = 5 THEN LEFT(V.CustomerIdentification,2)+L3.CustomerLocationCode
			WHEN V.CustomerID <> @GMCustomerID AND DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) <> 0 THEN L3.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END ShipFromLocationID,
		L3.LocationName, 	--ShipFromName
		ISNULL(L3.AddressLine1,'TBD'),	--ShipFromAddressLine1
		ISNULL(L3.AddressLine2,''),	--ShipFromAddressLine2
		L3.City,	--ShipFromCity
		L3.State,	--ShipFromState
		L3.Zip,		--ShipFromPostalCode
		CASE WHEN L3.Country = 'U.S.A.' THEN 'US' WHEN L3.Country = 'Canada' THEN 'CA' ELSE '' END,	--ShipFromCountry
		@ShipToStopSequence,
		@ShipToStopType,
		@ShipToStopRole,
		@ShipToEarlyArrival,
		@ShipToLateArrival,
		@ShipToStopDuration,
		@ShipToLocationIDQualilfier,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = @FVLocationCodeType AND Value1 = CONVERT(varchar(10),L4.LocationID))
			WHEN V.CustomerID = @GMCustomerID AND DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) = 8 THEN REPLACE(L4.CustomerLocationCode,'-','')
			WHEN V.CustomerID = @GMCustomerID AND DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) = 5 THEN LEFT(V.CustomerIdentification,2)+L4.CustomerLocationCode
			WHEN V.CustomerID <> @GMCustomerID AND DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) <> 0 THEN L4.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END ShipToLocationID,
		@ShipToName,
		@ShipToAddressLine1,
		@ShipToAddressLine2,
		@ShipToCity,
		@ShipToState,
		@ShipToPostalCode,
		@ShipToCountry,
		@ShipToQuantity,
		@StopReferenceQualifier,
		@StopReferenceDescription,
		@StopReferenceValue,
		V.VIN,
		@ShipmentReferenceQualifier,
		@ShipmentReferenceDescription,
		L2.LoadNumber,	--ShipmentReferenceValue
		@Latitude,
		@Longitude,
		L.PickupDate, --EventDate
		@Event,
		@EventReason,
		@ExportedInd,
		@RecordStatus,
		@CreationDate,
		@CreatedBy,
		V.CustomerID
	FROM Vehicle V
	LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
	LEFT JOIN Loads L2 ON L.LoadID = L2.LoadsID
	LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
	LEFT JOIN Location L4 ON V.DropoffLocationID = L4.LocationID
	LEFT JOIN Driver D ON L2.DriverID = D.DriverID
	LEFT JOIN Truck T ON D.CurrentTruckID = T.TruckID
	WHERE V.CustomerID = @CustomerID
	--AND DATALENGTH(ISNULL(L.FreightVerifyShipmentID,'')) > 0	--if this is populated then most of the other checks were already completed -- 09/12/2019 - CMK - removed check for earlier CP and LO generation
	--AND L.PickupDate IS NOT NULL -- 09/12/2019 - CMK - removed check for earlier CP and LO generation
	AND L.PickupDate >= @FreightVerifyStartDate -- 09/12/2019 - CMK - added check for earlier CP and LO generation
	AND L.LegStatus IN ('EnRoute','Delivered', 'Complete')
	AND V.VehicleID NOT IN (SELECT FV.VehicleID FROM FreightVerifyExportVehicleVisibility FV WHERE FV.Event = 'CP')
	--AND (CONVERT(varchar(10),V.PickupLocationID) IN (SELECT C.Value1 FROM Code C WHERE C.CodeType = 'FV'+@Customer+'LocationCode')
	--OR L3.ParentRecordTable <> 'Common')
	AND L3.City IS NOT NULL		-- 09/12/2019 - CMK - added check for earlier CP and LO generation
	AND L3.State IS NOT NULL	-- 09/12/2019 - CMK - added check for earlier CP and LO generation
	AND L3.Zip IS NOT NULL		-- 09/12/2019 - CMK - added check for earlier CP and LO generation
	AND L3.Country IS NOT NULL	-- 09/12/2019 - CMK - added check for earlier CP and LO generation
	AND DATALENGTH(ISNULL(V.CustomerIdentification,'')) >= 2	-- 09/12/2019 - CMK - added check for earlier CP and LO generation
	--ORDER BY L2.LoadNumber, L.FreightVerifyShipmentID		-- 09/12/2019 - CMK - old order by modified for earlier CP and LO generation
	ORDER BY L2.LoadNumber, ShipFromLocationID	-- 09/12/2019 - CMK - modified order by for earlier CP and LO generation
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error creating Asset Assigned records'
		GOTO Error_Encountered
	END
		
	--end of process the Pickup Complete records
	
	--process the Dropoff Complete records
		
	--Asset Assigned defaults
	SELECT @ProNumber = ''
	SELECT @TelematicProvider = 'self'
	SELECT @ShipUnitsTotalQuantity = NULL
	SELECT @TrailerType = ''
	SELECT @TeamDrivers = ''
	SELECT @Hazmat = ''
	SELECT @ShipFromStopSequence = NULL
	SELECT @ShipFromStopType = ''
	SELECT @ShipFromStopRole = ''
	SELECT @ShipFromEarlyArrival = NULL
	SELECT @ShipFromLateArrival = NULL
	SELECT @ShipFromStopDuration = ''
	SELECT @ShipFromLocationIDQualilfier = ''
	SELECT @ShipFromLocationID = ''
	SELECT @ShipFromName = ''
	SELECT @ShipFromAddressLine1 = ''
	SELECT @ShipFromAddressLine2 = ''
	SELECT @ShipFromCity = ''
	SELECT @ShipFromState = ''
	SELECT @ShipFromPostalCode = ''
	SELECT @ShipFromCountry = ''
	SELECT @ShipFromStopDuration = ''
	SELECT @ShipFromStopType = ''
	SELECT @ShipFromStopRole = ''
	SELECT @ShipFromEarlyArrival = NULL
	SELECT @ShipFromLateArrival = NULL
	SELECT @ShipFromStopDuration = ''
	SELECT @ShipToLocationIDQualilfier = 'customer'
	SELECT @ShipToStopSequence = 2
	SELECT @ShipToStopType = ''
	SELECT @ShipToStopRole = ''
	SELECT @ShipToEarlyArrival = NULL
	SELECT @ShipToLateArrival = NULL
	SELECT @ShipToQuantity = NULL
	SELECT @StopReferenceQualifier = ''
	SELECT @StopReferenceDescription = ''
	SELECT @StopReferenceValue = ''
	SELECT @StopReferenceQualifier = ''
	SELECT @StopReferenceDescription = ''
	SELECT @ShipmentReferenceQualifier = 'bol'
	SELECT @ShipmentReferenceDescription = 'bill of lading'
	SELECT @Latitude = NULL
	SELECT @Longitude = NULL
	SELECT @Event = 'D1'
	SELECT @EventReason = 'NS'

	INSERT INTO FreightVerifyExportVehicleVisibility (BatchID, VehicleID, LegsID, CarrierID, CarrierSCAC, Customer, ShipmentIdentification,
		ProNumber, TelematicProvider, TrackingAssetID, ShipUnitsTotalQuantity, TrailerType, TrailerNumber, TeamDrivers, Hazmat,
		ShipFromStopSequence, ShipFromStopType, ShipFromStopRole, ShipFromEarlyArrival, ShipFromLateArrival, ShipFromStopDuration,
		ShipFromLocationIDQualilfier, ShipFromLocationID, ShipFromName, ShipFromAddressLine1, ShipFromAddressLine2, ShipFromCity,
		ShipFromState, ShipFromPostalCode, ShipFromCountry, ShipToStopSequence, ShipToStopType, ShipToStopRole, ShipToEarlyArrival,
		ShipToLateArrival, ShipToStopDuration, ShipToLocationIDQualilfier, ShipToLocationID, ShipToName, ShipToAddressLine1,
		ShipToAddressLine2, ShipToCity, ShipToState, ShipToPostalCode, ShipToCountry, ShipToQuantity, StopReferenceQualifier,
		StopReferenceDescription, StopReferenceValue, VIN, ShipmentReferenceQualifier, ShipmentReferenceDescription,
		ShipmentReferenceValue, Latitude, Longitude, EventDate, Event, EventReason, ExportedInd, RecordStatus, CreationDate,
		CreatedBy, CustomerID)
		SELECT @BatchID,
		V.VehicleID,
		L.LegsID,
		@CarrierID,
		@CarrierSCAC,
		@Customer,
		L.FreightVerifyShipmentID,	--ShipmentIdentification
		@ProNumber,
		@TelematicProvider,
		T.TruckNumber,	--TrackingAssetID
		@ShipUnitsTotalQuantity,
		@TrailerType,
		T.TruckNumber,	--TrailerNumber
		@TeamDrivers,
		@Hazmat,
		@ShipFromStopSequence,
		@ShipFromStopType,
		@ShipFromStopRole,
		@ShipFromEarlyArrival,
		@ShipFromLateArrival,
		@ShipFromStopDuration,
		@ShipFromLocationIDQualilfier,
		@ShipFromLocationID,
		@ShipFromName,
		@ShipFromAddressLine1,
		@ShipFromAddressLine2,
		@ShipFromCity,
		@ShipFromState,
		@ShipFromPostalCode,
		@ShipFromCountry,
		@ShipToStopSequence,
		@ShipToStopType,
		@ShipToStopRole,
		@ShipToEarlyArrival,
		@ShipToLateArrival,
		@ShipToStopDuration,
		@ShipToLocationIDQualilfier,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = @FVLocationCodeType AND Value1 = CONVERT(varchar(10),L4.LocationID))
			WHEN V.CustomerID = @GMCustomerID AND DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) = 8 THEN REPLACE(L4.CustomerLocationCode,'-','')
			WHEN V.CustomerID = @GMCustomerID AND DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) = 5 THEN LEFT(V.CustomerIdentification,2)+L4.CustomerLocationCode
			WHEN V.CustomerID <> @GMCustomerID AND DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) <> 0 THEN L4.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END ShipToLocationID,
		L4.LocationName,	--ShipToName,
		ISNULL(L4.AddressLine1,'TBD'),	--ShipToAddressLine1,
		ISNULL(L4.AddressLine2,''),	--ShipToAddressLine2,
		L4.City,	--ShipToCity,
		L4.State,	--ShipToState,
		L4.Zip,	--ShipToPostalCode,
		CASE WHEN L4.Country = 'U.S.A.' THEN 'US' WHEN L4.Country = 'Canada' THEN 'CA' ELSE '' END,	--ShipToCountry,
		@ShipToQuantity,
		@StopReferenceQualifier,
		@StopReferenceDescription,
		@StopReferenceValue,
		V.VIN,
		@ShipmentReferenceQualifier,
		@ShipmentReferenceDescription,
		L2.LoadNumber,	--ShipmentReferenceValue
		@Latitude,
		@Longitude,
		L.DropoffDate, --EventDate
		@Event,
		@EventReason,
		@ExportedInd,
		@RecordStatus,
		@CreationDate,
		@CreatedBy,
		V.CustomerID
	FROM Vehicle V
	LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
	LEFT JOIN Loads L2 ON L.LoadID = L2.LoadsID
	LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
	LEFT JOIN Location L4 ON V.DropoffLocationID = L4.LocationID
	LEFT JOIN Driver D ON L2.DriverID = D.DriverID
	LEFT JOIN Truck T ON D.CurrentTruckID = T.TruckID
	WHERE V.CustomerID = @CustomerID
	AND DATALENGTH(ISNULL(L.FreightVerifyShipmentID,'')) > 0	--if this is populated then most of the other checks were already completed
	AND L.DropoffDate IS NOT NULL
	AND L.LegStatus IN ('Complete', 'Delivered')
	AND V.VehicleID NOT IN (SELECT FV.VehicleID FROM FreightVerifyExportVehicleVisibility FV WHERE FV.Event = 'D1')
	--AND (CONVERT(varchar(10),V.PickupLocationID) IN (SELECT C.Value1 FROM Code C WHERE C.CodeType = 'FV'+@Customer+'LocationCode')
	--OR L3.ParentRecordTable <> 'Common')
	ORDER BY L2.LoadNumber, L.FreightVerifyShipmentID
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error creating Asset Assigned records'
		GOTO Error_Encountered
	END
		
	--end of process the Dropoff Complete records
	
	--process the Location Update records
			
	--Asset Assigned defaults
	SELECT @TelematicProvider = 'self'
	SELECT @ShipUnitsTotalQuantity = NULL
	SELECT @TrailerType = ''
	SELECT @TeamDrivers = ''
	SELECT @Hazmat = ''
	SELECT @ShipFromStopSequence = NULL
	SELECT @ShipFromStopType = ''
	SELECT @ShipFromStopRole = ''
	SELECT @ShipFromEarlyArrival = NULL
	SELECT @ShipFromLateArrival = NULL
	SELECT @ShipFromStopDuration = ''
	SELECT @ShipFromLocationIDQualilfier = ''
	SELECT @ShipFromName = ''
	SELECT @ShipFromAddressLine1 = ''
	SELECT @ShipFromAddressLine2 = ''
	SELECT @ShipFromCity = ''
	SELECT @ShipFromState = ''
	SELECT @ShipFromPostalCode = ''
	SELECT @ShipFromCountry = ''
	SELECT @ShipFromStopDuration = ''
	SELECT @ShipFromStopType = ''
	SELECT @ShipFromStopRole = ''
	SELECT @ShipFromEarlyArrival = NULL
	SELECT @ShipFromLateArrival = NULL
	SELECT @ShipFromStopDuration = ''
	SELECT @ShipToStopSequence = NULL
	SELECT @ShipToStopType = ''
	SELECT @ShipToStopRole = ''
	SELECT @ShipToEarlyArrival = NULL
	SELECT @ShipToLateArrival = NULL
	SELECT @ShipToStopDuration = ''
	SELECT @ShipToLocationIDQualilfier = ''
	SELECT @ShipToName = ''
	SELECT @ShipToAddressLine1 = ''
	SELECT @ShipToAddressLine2 = ''
	SELECT @ShipToCity = ''
	SELECT @ShipToState = ''
	SELECT @ShipToPostalCode = ''
	SELECT @ShipToCountry = ''
	SELECT @ShipToQuantity = NULL
	SELECT @StopReferenceQualifier = ''
	SELECT @StopReferenceDescription = ''
	SELECT @StopReferenceValue = ''
	SELECT @StopReferenceQualifier = ''
	SELECT @StopReferenceDescription = ''
	SELECT @ShipmentReferenceQualifier = 'bol'
	SELECT @ShipmentReferenceDescription = 'bill of lading'
	SELECT @Event = 'LO'
	SELECT @EventReason = 'NS'
	
	INSERT INTO FreightVerifyExportVehicleVisibility (BatchID, VehicleID, LegsID, CarrierID, CarrierSCAC, Customer, ShipmentIdentification,
		ProNumber, TelematicProvider, TrackingAssetID, ShipUnitsTotalQuantity, TrailerType, TrailerNumber, TeamDrivers, Hazmat,
		ShipFromStopSequence, ShipFromStopType, ShipFromStopRole, ShipFromEarlyArrival, ShipFromLateArrival, ShipFromStopDuration,
		ShipFromLocationIDQualilfier, ShipFromLocationID, ShipFromName, ShipFromAddressLine1, ShipFromAddressLine2, ShipFromCity,
		ShipFromState, ShipFromPostalCode, ShipFromCountry, ShipToStopSequence, ShipToStopType, ShipToStopRole, ShipToEarlyArrival,
		ShipToLateArrival, ShipToStopDuration, ShipToLocationIDQualilfier, ShipToLocationID, ShipToName, ShipToAddressLine1,
		ShipToAddressLine2, ShipToCity, ShipToState, ShipToPostalCode, ShipToCountry, ShipToQuantity, StopReferenceQualifier,
		StopReferenceDescription, StopReferenceValue, VIN, ShipmentReferenceQualifier, ShipmentReferenceDescription,
		ShipmentReferenceValue, Latitude, Longitude, EventDate, Event, EventReason, ExportedInd, RecordStatus, CreationDate,
		CreatedBy, CustomerID)
		SELECT @BatchID,
		V.VehicleID,
		L.LegsID,
		@CarrierID,
		@CarrierSCAC,
		@Customer,
		L.FreightVerifyShipmentID,	--ShipmentIdentification
		L2.LoadNumber,	--ProNumber
		@TelematicProvider,
		T.TruckNumber,	--TrackingAssetID
		@ShipUnitsTotalQuantity,
		@TrailerType,
		T.TruckNumber,	--TrailerNumber
		@TeamDrivers,
		@Hazmat,
		@ShipFromStopSequence,
		@ShipFromStopType,
		@ShipFromStopRole,
		@ShipFromEarlyArrival,
		@ShipFromLateArrival,
		@ShipFromStopDuration,
		@ShipFromLocationIDQualilfier,
		CASE WHEN L3.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = @FVLocationCodeType AND Value1 = CONVERT(varchar(10),L3.LocationID))
			WHEN V.CustomerID = @GMCustomerID AND DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) = 8 THEN REPLACE(L3.CustomerLocationCode,'-','')
			WHEN V.CustomerID = @GMCustomerID AND DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) = 5 THEN LEFT(V.CustomerIdentification,2)+L3.CustomerLocationCode
			WHEN V.CustomerID <> @GMCustomerID AND DATALENGTH(ISNULL(L3.CustomerLocationCode,'')) <> 0 THEN L3.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L3.SPLCCode,'')) > 0 THEN L3.SPLCCode END ShipFromLocationID,
		@ShipFromName,
		@ShipFromAddressLine1,
		@ShipFromAddressLine2,
		@ShipFromCity,
		@ShipFromState,
		@ShipFromPostalCode,
		@ShipFromCountry,
		@ShipToStopSequence,
		@ShipToStopType,
		@ShipToStopRole,
		@ShipToEarlyArrival,
		@ShipToLateArrival,
		@ShipToStopDuration,
		@ShipToLocationIDQualilfier,
		CASE WHEN L4.ParentRecordTable = 'Common' THEN (SELECT TOP 1 Code FROM Code WHERE CodeType = @FVLocationCodeType AND Value1 = CONVERT(varchar(10),L4.LocationID))
			WHEN V.CustomerID = @GMCustomerID AND DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) = 8 THEN REPLACE(L4.CustomerLocationCode,'-','')
			WHEN V.CustomerID = @GMCustomerID AND DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) = 5 THEN LEFT(V.CustomerIdentification,2)+L4.CustomerLocationCode
			WHEN V.CustomerID <> @GMCustomerID AND DATALENGTH(ISNULL(L4.CustomerLocationCode,'')) <> 0 THEN L4.CustomerLocationCode
			WHEN DATALENGTH(ISNULL(L4.SPLCCode,'')) > 0 THEN L4.SPLCCode END ShipToLocationID,
		@ShipToName,
		@ShipToAddressLine1,
		@ShipToAddressLine2,
		@ShipToCity,
		@ShipToState,
		@ShipToPostalCode,
		@ShipToCountry,
		@ShipToQuantity,
		@StopReferenceQualifier,
		@StopReferenceDescription,
		@StopReferenceValue,
		V.VIN,
		@ShipmentReferenceQualifier,
		@ShipmentReferenceDescription,
		L2.LoadNumber,	--ShipmentReferenceValue
		T.LastLatReported,
		T.LastLongReported,
		T.LastLatLongDateTime, --EventDate
		@Event,
		@EventReason,
		@ExportedInd,
		@RecordStatus,
		@CreationDate,
		@CreatedBy, V.CustomerID
	FROM Vehicle V
	LEFT JOIN Legs L ON V.VehicleID = L.VehicleID
	LEFT JOIN Loads L2 ON L.LoadID = L2.LoadsID
	LEFT JOIN Driver D ON L2.DriverID = D.DriverID
	LEFT JOIN Truck T ON D.CurrentTruckID = T.TruckID
	LEFT JOIN Location L3 ON V.PickupLocationID = L3.LocationID
	LEFT JOIN Location L4 ON V.DropoffLocationID = L4.LocationID
	WHERE V.CustomerID = @CustomerID
	--AND DATALENGTH(ISNULL(L.FreightVerifyShipmentID,'')) > 0	--if this is populated then most of the other checks were already completed -- 09/12/2019 - CMK - modified order by for earlier CP and LO generation
	--AND T.LastLatLongDateTime >= L.PickupDate	-- 09/12/2019 - CMK - modified order by for earlier CP and LO generation
	--AND L.LegStatus = 'EnRoute'
	AND (L.LegStatus = 'EnRoute'
	OR (L.LegStatus IN ('Delivered','Complete')
	AND DATEADD(minute,30,L.DropoffDate) >= CURRENT_TIMESTAMP))
	--AND (CONVERT(varchar(10),V.PickupLocationID) IN (SELECT C.Value1 FROM Code C WHERE C.CodeType = 'FV'+@Customer+'LocationCode')
	--OR L3.ParentRecordTable <> 'Common')
	ORDER BY L2.LoadNumber, L.FreightVerifyShipmentID
	IF @@Error <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error creating Asset Assigned records'
		GOTO Error_Encountered
	END
			
	--end of process the Location Update records
	
	--set the next batch id in the setting table
	UPDATE SettingTable
	SET ValueDescription = @BatchID+1	
	WHERE ValueKey = 'NextFreightVerifyVehicleVisibilityExportBatchID'
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrorID = @@ERROR
		SELECT @Status = 'Error Setting BatchID'
		GOTO Error_Encountered
	END
		
	Error_Encountered:
	IF @ErrorID = 0
	BEGIN
		--COMMIT TRAN
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		--ROLLBACK TRAN
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END

	Error_Encountered2:
	IF @ErrorID = 0
	BEGIN
		SELECT @ReturnCode = 0
		SELECT @ReturnMessage = 'Processing Completed Successfully'
		GOTO Do_Return
	END
	ELSE
	BEGIN
		SELECT @ReturnCode = @ErrorID
		SELECT @ReturnMessage = @Status
		GOTO Do_Return
	END
	
	Do_Return:
	SELECT @ReturnCode AS ReturnCode, @ReturnMessage AS ReturnMessage, @BatchID AS BatchID
	
	RETURN
END
GO

GRANT  EXECUTE  ON [dbo].[spGenerateFreightVerifyVehicleVisibilityData]  TO [db_sp_execute]
GO