/*
  Copyright (C) 2015  SpiffSpaceman

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>
*/

// NOW - NestPlus DataTable Backfill

dtBackFill(){
	global																	// This Declares function global - all variables global except local ones	
																			// Need to use DT1, DT2 etc
	
	TradingSymbolColIndex := getColumnIndex( "Trading Symbol" )				// Get Position of Trading Symbol Column in Market Watch
	if( TradingSymbolColIndex == -1) { 
		MsgBox, Trading Symbol not found in Market Watch
		Exit
	}
	
	Loop, %DTCount% {
				
		local fields := StrSplit( DT%A_Index% , ",")  						// Format - TradingSymbol,Alias
		
		if( fields[3] == "EOD" && !isMarketClosed() )						// Skip EOD Scrips during the day
			continue
				
		if( openDataTable( fields[1], 0 ) )									// Write Scrip data if loaded
			writeDTData( fields[2] )
	}	
}

indexBackFill(){															// NOTE - This wont work if Index has scroll bars
	global

	Loop, %IndexCount% {
		
		local fields := StrSplit( Index%A_Index% , ",")  					// Format - IndexSymbol,Alias
		
		if( fields[3] == "EOD" && !isMarketClosed() )						// Skip EOD Scrips during the day
			continue
		
		if( openIndexDataTable( fields[1] ) )
			writeDTData( fields[2] )
	}	

	closeNestPlusChart()													// Close Nest Plus chart when All done
}




// ------- Private --------

getColumnIndex( inColumnHeaderText ){										// Gets ListView Column Number for input Header text
	global NowWindowTitle
	
	MWHeaders := GetExternalHeaderText( NowWindowTitle, "SysHeader323")	

	for index, headertext in MWHeaders{
		if( headertext == inColumnHeaderText )
			return index
	}	
	
	return -1
}

openDataTable( inTradingSymbol, retryCount ){
	
	global NowWindowTitle, DTWindowTitle, TradingSymbolColIndex
	
	WinClose, %DTWindowTitle%	 											// Close DT If already Opened	
	
	Loop, 3{																// Sometimes {HOME} does not work when NOW is active - try 3 times
		ControlGet, RowCount, List, Count, SysListView323, %NowWindowTitle%		// No of rows in MarketWatch	
		ControlSend, SysListView323, {Home 2}, %NowWindowTitle%					// Start from top and search for scrip
					
		Loop, %RowCount%{														// Select row with our scrip		
			ControlGet, RowSymbol, List, Selected Col%TradingSymbolColIndex%, SysListView323, %NowWindowTitle%							
																				// Take Trading Symbol from column Number in %TradingSymbolColIndex%		
			if( RowSymbol = inTradingSymbol ){									// and compare it with input 
				 break
			}
			ControlSend, SysListView323, {Down}, %NowWindowTitle%				// Move Down to next row if not found yet
		}		
		if( RowSymbol = inTradingSymbol )
			break		
	}
	if ( RowSymbol != inTradingSymbol ) {
		MsgBox, %inTradingSymbol% Not Found.
		Exit
	}	
		
	ControlSend, SysListView323, {Shift Down}d{Shift Up}, %NowWindowTitle%  // At this point row should be selected. Open Data Table with shift-d 		
																			// Note - This also selects scrip starting with d in MW. Check 
	
	if( !waitforDTOpen( inTradingSymbol, retryCount, 5, 5 ) ) {				// Wait for DataTable to open and load
		openDataTable( inTradingSymbol, retryCount+1  )
	}
	
	isDataLoaded := waitForDTData( inTradingSymbol )	
	WinMinimize, %DTWindowTitle% 
	
	return isDataLoaded
}

openIndexDataTable( inIndexSymbol ){
	
	global  NowWindowTitle, DTWindowTitle		
	RowSymbol := ""
	
	WinClose, %DTWindowTitle%	 											// Close DT If already Opened	
	ControlGet,  RowCount, List, Count, SysListView324, %NowWindowTitle%	// No of rows in Index Dialog	
	ControlSend, SysListView324, {HOME}, %NowWindowTitle%					// Start from top and search for Index
																			
	Loop, %RowCount%{														
		ControlGet, RowSymbol, List, Selected Col1, SysListView324, %NowWindowTitle%																			
		if( RowSymbol = inIndexSymbol ){									// Assuming 1st column has Index names, compare with input
			RowNumber = %A_Index%
			break
		}
		ControlSend, SysListView324, {Down}, %NowWindowTitle%				// Move Down to next row if not found yet
	}	
	
	if ( RowSymbol != inIndexSymbol ) {
		MsgBox, %inIndexSymbol% Not Found.
		Exit
	}
	
	ControlGetPos, IndexX, IndexY, IndexWidth, IndexHeight, SysListView324, %NowWindowTitle%	
	RowSize := IndexHeight/RowCount											// Get Position of Index Row
	ClickX  := IndexX + IndexWidth/2										// Middle of Index box
	ClickY  := IndexY + RowNumber*RowSize - RowSize/2						// Somewhere within the Row
		
	ControlClick, X%ClickX% Y%ClickY%, %NowWindowTitle%,, RIGHT,,NA			// Right Click on Index Row
	ControlSend,  SysListView324, {P}, %NowWindowTitle%		 				// Open Chart	
		
	WinWait, %NowWindowTitle%, IntraDay Chart, 30							// Wait for Chart Control to load - Waiting for Text 'IntraDay Chart'	
	
	if( ErrorLevel ){ 														// Chart open timeout		
		MsgBox, Nest Plus Chart Open Timed Out.
		Exit	
	}			
	
	Loop{																	// Wait for DataTable to open and load
		WinClose, %DTWindowTitle%
		ControlClick, Static7, 		%NowWindowTitle%,, RIGHT,,NA			// Open Datatable 
		ControlSend,  Static7, {D}, %NowWindowTitle%	
	}
	Until waitforDTOpen( inIndexSymbol, A_Index, 5, 5 )						// Check upto 5 times. Check every 5 seconds

	isDataLoaded := waitForDTData( inIndexSymbol )
	WinMinimize, %DTWindowTitle%
	
	return isDataLoaded
}

waitforDTOpen( symbol, i, maxI, waitTime  ){								// returns true if Datatable is open
	global DTWindowTitle
	
	SetTitleMatchMode, RegEx
	
	WinWait, %DTWindowTitle%.*%symbol%,, 1									// Wait for Data Table to open - Look for DTWindowTitle and Scrip name
	IfWinExist, Update Holdings/Collateral									// Workaround fix - When NOW is active, sometimes opening DT also opens Update Holdings
	{																			// So close it. Check why this opens
		WinClose, Update Holdings/Collateral
		SetTitleMatchMode, 2
		return false
	}
	WinWait, %DTWindowTitle%.*%symbol%,, % (waitTime-1)
	
	SetTitleMatchMode, 2													// If not opened, we will call openDataTable again
		
	if ErrorLevel {															// Sometimes shortcut does not work with NOW focussed , try again
		checkPlusLoginPrompt()
		if( i >= maxI ){
			MsgBox, DataTable for %symbol% did not open.	
			Exit
		}		
		return false
	}
	
	return true
}

waitForDTData( symbol  ){
	global DTWindowTitle
		
	ExpectedCount := getExpectedDataRowCount()								// Assuming NestPlus No of days is set to 1 day 
																			// Still, NestPlus seems to load latest first which should also work
	Loop, 10 {
		ControlGet, rowCount, List, Count, SysListView321, %DTWindowTitle% 
	
		if( rowCount >= ExpectedCount ){									// Initial Simple Wait without checking for contents. Wait Max 5 seconds
			break		
		}
		Sleep 500
	}	
																			// TODO move to c++ - takes long time
	Loop {																	// Check all data loaded. Count only valid intraday quotes		
		rowCount := 0														// Ignore duplicates. And Count Only quotes within market hour Today
		ControlGet, date_time, List, Col2, SysListView321, %DTWindowTitle%	// Assuming Date Time Column at default position
		Sort, date_time, U 													// Sort, Remove duplicates		
		Loop, Parse, date_time, `n  										// Get Number of rows
		{
			dateTimeSplit   := StrSplit( A_LoopField, " ") 					// 05-11-2015 15:29:00
			if( !isDateToday( dateTimeSplit[1] )  )
				continue
			
			timeSplit := StrSplit( dateTimeSplit[2], ":")
			
			if( isTimeInMarketHours( timeSplit[1] . ":" . timeSplit[2] ) )  
				rowCount++
		}
		
		if( rowCount >= ExpectedCount ){									// All data loaded
			return true
		}	
	
		if( A_Index == 10 ){
			WinRestore, %DTWindowTitle%										// sometimes data doesnt load if window is minimized ? 
		}
		if( Mod(A_Index, 20 )==0 ){											// Ask Every 20 seconds if all data has not yet been received
			missingCount := ExpectedCount - rowCount
			MsgBox, 4, %symbol% - Waiting, DataTable for %symbol% has %missingCount% minutes missing. Is Data still loading?
			IfMsgBox No
			{
				MsgBox, 4,  %symbol% - Waiting, Do you still want to Backfill %symbol% with this data ?
				IfMsgBox yes
					return true
				Else
					return false
			}
		}
		Sleep 1000
	}
	
	return false
}

/* Click Works on NestChart close button But ControlClick does not work
	Also, No Control detected name for close button
	So just get XY coordinates, activate window, click and go back to original state
	There may be a better workaround using PostMessage
*/
closeNestPlusChart(){
	global NowWindowTitle, DTWindowTitle	
	
	ControlGetPos, X, Y, Width, Height, AfxControlBar1006, %NowWindowTitle%		
	ClickX  := X + 5
	ClickY  := Y + 15				
	
	CoordMode, Mouse, Screen												// Save Mouse position
	BlockInput, MouseMove	
    MouseGetPos, oldx, oldy
	
	SetTitleMatchMode, RegEx
	hidden := false
	IfWinNotActive, .*%NowWindowTitle%.*|.*%DTWindowTitle%.*
	{																		// Hide Window to avoid showing it when another window  is active
		WinSet, Transparent, 1, %NowWindowTitle%							// 0 seems to have extra side effects, Window gets minimized?
		WinGetTitle, currentWindow, A 										// Save active window	
		WinActivate, %NowWindowTitle%	
		hidden := true
	}
	SetTitleMatchMode, 2
	
	CoordMode, Mouse, Relative												// click button	
	Click %ClickX%, %ClickY% 		
	Sleep, 50																// Wait for click to work.

	if( hidden == true ){
		WinActivate, %currentWindow%										// restore active window		
		WinSet, Transparent, 255, %NowWindowTitle%		
	}
	
	CoordMode, Mouse, Screen												// restore mouse position
	MouseMove, %oldx%, %oldy%, 0	
	BlockInput, MouseMoveOff
	CoordMode, Mouse, Relative		
}

writeDTData( inAlias )														// columns expected order - TradingSymbol Time O H L C V
{
	global DTWindowTitle, DTBackfillFileName	
	
	ControlGet, data, List, , SysListView321, %DTWindowTitle%				// Copy Data
	WinClose, %DTWindowTitle%	 											// Close DT and Chart		
	
	createFileDirectory( DTBackfillFileName )
	
	file := FileOpen(DTBackfillFileName, "a" )
	if !IsObject(file){
		MsgBox, Can't open DT backfill file for writing.
		Exit
	}
		
	AliasText := "name=" . inAlias
	file.WriteLine(AliasText)												// Append AB Scrip Name
	file.Write(data)							    						// Add Data
	file.Write("`n")							    						// Add newline
	file.Close()
}

checkPlusLoginPrompt(){
	IfWinExist, ,If you do not have a PLUS ID
	{ 
		MsgBox, NestPlus Login.
		Exit
	}	
}
