//
// Console.pas
//
// Console Manipulation.
// NOTE: These procedures do not have protection , WriteConsole should not have trouble but ReadConsole may face race condition when running from two CPUS
// 
// Changes:
// 27 / 03 / 2009: Adding support for QWORD parameters in Printk_() and WriteConsole().
// 08 / 02 / 2007: Rename to Console.pas  , new procedures to read and write the console by Matias Vara.
// The consoles's procedures are only for users , the kernel only need PrintK_()
// 15 / 07 / 2006 : The code was rewrited  by Matias Vara .
// 09 / 02 / 2005 :  First Version by Matias Vara .
//
// Copyright (c) 2003-2011 Matias Vara <matiasvara@yahoo.com>
// All Rights Reserved
//
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

unit Console;

{$I ../Toro.inc}

interface

uses Arch, Process;

procedure CleanConsole;
procedure PrintDecimal(Value: PtrUInt);
procedure PrintK_(Format: PXChar; Arg: PtrUInt);
procedure WriteConsole(const Format: AnsiString; const Args: array of PtrUInt);
procedure ReadConsole(var C: XChar);
procedure ReadlnConsole(Format: PXChar);
procedure DisabledConsole;
procedure EnabledConsole;
procedure ConsoleInit;

var
 Color: Byte = 10;

const
  HEX_CHAR: array[0..15] of XChar = ('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F');

implementation

const
    CHAR_CODE : array [1..57] of XChar =
   ('0','1','2','3','4','5','6','7','8','9','0','?','=','0',' ','q','w',
   'e','r','t','y','u','i','o','p','[',']','0','0','a','s','d','f','g','h',
   'j','k','l','�','{','}','0','0','z','x','c','v','b','n','m',',','.','-',
   '0','*','0',' ');

const
	VIDEO_OFFSET = $B8000;

type
	TConsole = record // screen text mode
		car: XChar;
		form: Byte;
	end;

procedure PrintString(const S: AnsiString); forward;

var
  PConsole: ^TConsole;
  X, Y: Byte;
  KeyBuffer: array[1..127] of XChar;
  BufferCount: LongInt;
  ThreadInKey: PThread;
  LastChar: LongInt;
	
// position the cursor in screen 
procedure SetCursor(X, Y: Byte);
begin
	write_portb($0E, $3D4);
	write_portb(Y, $3D5);
	write_portb($0f, $3D4);
	write_portb(X, $3D5);
end;

// Put caracter to screen 
procedure PutC(const Car: XChar);
begin
  Y := 24;
  if X > 79 then
  X := 0;
  PConsole := Pointer(VIDEO_OFFSET + (80*2)*Y + (X*2));
  PConsole.form := color;
  PConsole.car := Car;
  X := X+1;
  SetCursor(X, Y);
end;

{$IFDEF DCC}
procedure FillWord(var X; Count: Integer; Value: Word);
type
  wordarray    = array [0..high(Integer) div 2-1] of Word;
var
  I: Integer;
begin
  for I := 0 to Count-1 do
    wordarray(X)[I] := Value;
end;
{$ENDIF}

// Flush up the screen 
procedure FlushUp;
begin
  X := 0 ;
  Move(PXChar(VIDEO_OFFSET+160)^, PXChar(VIDEO_OFFSET)^, 24*80*2);
  FillWord(PXChar(VIDEO_OFFSET+160*24)^, 80, $0720);
end;

// Print in decimal form
procedure PrintDecimal(Value: PtrUInt);
var
  I, Len: Byte;
  S: string[64];
begin
  Len := 0;
  I := 10;
  if Value = 0 then
  begin
    PutC('0');
  end else
  begin
    while Value <> 0 do
    begin
      S[I] := AnsiChar((Value mod 10) + $30);
    Value := Value div 10;
   I := I-1;
   Len := Len+1;
  end;
  if (Len <> 10) then
  begin
   S[0] := XChar(Len);
   for I := 1 to Len do
   begin
    S[I] := S[11-Len];
    Len := Len-1;
   end;
   end else
   begin
    S[0] := chr(10);
   end;
   for I := 1 to ord(S[0]) do
   begin
    PutC(S[I]);
   end;
  end;
end;

procedure PrintHexa(Value: PtrUInt);
var
  I: Byte;
begin
  PutC('0');
  PutC('x');
  for I := SizeOf(PtrUInt)*2-1 downto 0 do
    PutC(HEX_CHAR[(Value shr (I*4)) and $0F]);
end;

procedure PrintString(const S: AnsiString);
var
	I: Integer;
begin
	for I := 1 to Length(S) do
  	PutC(S[I]);
end;

// Clean the screen 
procedure CleanConsole;
begin
  FillWord(PXChar(video_offset)^, 2000, $0720);
	X := 0;
	Y := 0;
end;

// Format: pointer to char
// args: array of values
procedure PrintK_(Format: PXChar; Arg: PtrUInt);
var
  ArgNo: PtrUInt;
  I: LongInt;
begin
  ArgNo := 0 ;
  while Format^ <> #0 do
  begin
    // we have only one argument
    if (Format^ = '%') and (Argno = 0)then
    begin
      Inc(Format);
      if Format^ = #0 then
      	Exit ;
      case Format^ of
        'h': PrintHexa(Arg);
       	'd': PrintDecimal (Arg);
       	'%': PutC('%');
        else
      	  begin
        	  Format := Format+1;
          	Continue;
          end;
      end;
      Format := Format+1;
      ArgNo :=1;
      Continue;
    end;
    if Format^ = '\' then
    begin
    	Format := Format+1;
     	if Format^ = #0 then
      	Exit ;
      case Format^ of
       	'c': begin
        			 CleanConsole;
           		 Format := Format+1;
            end;
       	'n': begin
           		 FlushUp;
           		 Format := Format+1;
							 x := 0;
            end;
       	'\': begin
           		PutC('\');
           		Format := Format+1;
            end;
       	'v': begin
           		I := 1;
              while I < 10 do
              begin
              	PutC(' ');
                Inc(I);
              end;
              Format := Format+1;
           	end;
				else
       	begin
       		PutC('\');
        	PutC(Format^);
      	end;
      end;
      Continue;
    end;
    // Terminal Color indicator
    if Format^ = '/' then
    begin
      Format := Format+1;
      if Format^=#0 then
        Exit;
      case Format^ of
        'n': color := 7 ;
        'a': color := 1;
        'v': color := 2;
        'V': color := 10;
        'z': color := $f;
        'c': color := 3;
        'r': color := 4;
        'R': color := 12 ;
        'N': color := $af;
      end;
      Format := Format+1;
      Continue;
    end;
    PutC(Format^);
    Format := Format+1;
  end;
end;

// Print to screen using format
procedure WriteConsole(const Format: AnsiString; const Args: array of PtrUInt);
var
  ArgNo: LongInt;
  I, J: LongInt;
  Value: QWORD;
  Values: PXChar;
begin
  ArgNo := 0 ;
  J := 1;
  while J <= Length(Format) do
  begin
    // we have an argument
    if (Format[J] = '%') and (High(Args) <> -1) and (High(Args) >= ArgNo) then
    begin
      J:= J+1;
      if J > Length(Format) then
      	Exit ;
      case Format[J] of
	      'c':
          begin
		        PutC(XChar(args[ArgNo]));
			    end;
        'h':
          begin
            Value := args[ArgNo];
          	PrintHexa(Value);
          end;
     	  'd':
          begin
            Value := args[ArgNo];
          	PrintDecimal (Value);
          end;
     	  '%':
          begin
            PutC('%');
          end;
        'p':
          begin
            Values := pointer(args[ArgNo]);
            while Values^ <> #0 do
            begin
              PutC(Values^);
              Inc(Values);
            end;
          end;
      	else
      	begin
        	J:= J+1;
        	Continue;
        end;
      end;
      J:= J+1;
      ArgNo := ArgNo+1;
      Continue;
    end;
    if Format[J] = '\' then
    begin
    	J:= J+1;
     	if J > Length(Format) then
      	Exit ;
      case Format[J] of
       	'c': begin
        			 CleanConsole;
           		 J:=J+1;
            end;
       	'n': begin
           		 FlushUp;
           		 J:= J+1;
							 x := 0;
            end;
       	'\': begin
           		PutC('\');
           		J:=J+1;
            end;
       	'v':
          begin
            I := 1;
            while I < 10 do
            begin
              PutC(' ');
              Inc(I);
            end;
            J:=J+1;
          end;
				else
       	begin
       		PutC('\');
        	PutC(Format[J]);
      	end;
      end;
      Continue;
    end;
    // Terminal Color indicator
    if Format[J] = '/' then
    begin
      Inc(J);
      if Format[J] = #0 then
        Exit;
      case Format[J] of
        'n': color := 7 ;
        'a': color := 1;
        'v': color := 2;
        'V': color := 10;
        'z': color := $f;
        'c': color := 3;
        'r': color := 4;
        'R': color := 12 ;
        'N': color := $af;
      end;
      Inc(J);
      Continue;
    end;
    PutC(Format[J]);
    Inc(J);
  end;
end;

// Handler the irq of keyboard
procedure KeyHandler;
var
  key: Byte;
  pbuff: PXChar;
begin
  eoi;
  while (read_portb($64) and 1) = 1 do
  begin
    key:=read_portb($60);
    key:= 127 and key;
    // Shift and Crt key are not implement
    if key and 128 <> 0 then
      Exit;
    // Manipulation of keys
    case key of
      //Shift, Crt and CpsLockk are not implement
      29,42,58: Exit;
      14:
        begin
          //Bkspc key
          if x<>0 then
	        begin
	          x := x-1;
            PutC(#0);
            x:= x-1;
	          setcursor(x,y);
	        end;
        end;
      28:
        begin
          // Enter Key
	        y := y+1;
	        if y = 25 then
	          FlushUp;
	        SetCursor(x,y);
          BufferCount := BufferCount+1;
          if BufferCount > SizeOf(KeyBuffer) then
            BufferCount:=1;
          pbuff := @KeyBuffer[BufferCount];
	        pbuff^ := #13;
	        if ThreadinKey <> nil then
	          ThreadinKey.state:=tsReady;
        end;
      75,72,80,77: Continue;
      else
      begin
        // Printing the key to the screen
        Inc(BufferCount);
        if BufferCount > SizeOf(KeyBuffer) then
          BufferCount:=1;
        pbuff := @KeyBuffer[BufferCount];
	      pbuff^ := Char_Code[key];
	      PutC(pbuff^);
	      if ThreadinKey <> nil then
	        ThreadinKey.state:=tsReady;
      end;
    end;
  end;
end;


procedure IrqKeyb; {$IFDEF FPC} [nostackframe]; {$ENDIF} assembler;
asm
  {$IFDEF DCC} .noframe {$ENDIF}
  // save registers
  push rbp
  push rax
  push rbx
  push rcx
  push rdx
  push rdi
  push rsi
  push r8
  push r9
  push r13
  push r14
  // protect the stack
  mov r15 , rsp
  mov rbp , r15
  sub r15 , 32
  mov  rsp , r15
  // set interruption
  sti
  // call handler
  Call KeyHandler
  mov rsp , rbp
  // restore the registers
  pop r14
  pop r13
  pop r9
  pop r8
  pop rsi
  pop rdi
  pop rdx
  pop rcx
  pop rbx
  pop rax
  pop rbp
  db $48
  db $cf
end;

// Read a Char from Console
procedure ReadConsole(var C: XChar);
begin
  ThreadInkey := GetCurrentThread;
  if BufferCount = LastChar then
  begin
    ThreadInKey.state := tsIOPending;
    SysThreadSwitch;
  end;
  LastChar := LastChar+1;
  if LastChar > SizeOf(KeyBuffer) then
    LastChar := SizeOf(KeyBuffer);
  C := KeyBuffer[LastChar];
  ThreadInKey := nil;
end;

// Read the console until [Enter] key is pressed
procedure ReadlnConsole(Format: PXChar);
var
  C: XChar;
begin
  while True do
  begin
    ReadConsole(C);
    if C = #13 then
    begin
      Format^ := #0;
      Exit;
    end;
    Format^ := C;
    Inc(Format);
  end;
end;

procedure EnabledConsole;
begin
  irq_on(1);
end;

procedure DisabledConsole;
begin
  irq_off(1);
end;

procedure ConsoleInit;
begin
  BufferCount := 1;
  ThreadInKey := nil;
  LastChar := 1;
  CaptureInt(33,@IrqKeyb);
end;

end.
