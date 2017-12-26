{
    This unit is part of the flexlistview component.

    Copyright (c) 2017 by Andrew Haines.

    See the file COPYING.modifiedLGPL, included in this distribution.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

    Description:
      This is the base flexlistview classes which are not dependant on any gui
      components specifically.

      FlexListView aims to simplify mapping arbitrary data into custom views
      which can be scrolled using adapters.

      If you create a new adapter type it must implement IFlexListAdapter or
      alternatively you can descend from TFlexBaseAdapter and override the
      needed methods.
}
unit FlexListViewBase;

{$mode objfpc}{$H+}
{$interfaces corba}

interface

uses
  Classes, SysUtils, fgl;
type

  TAdapterChangeEvent = (acGrow, acShrink, acRebuild, acClear, acAttach, acDetach);


  IFlexListAdapterHolder = interface
    ['{F5B6ADF7-F068-404A-9118-F4637C35CB99}']
    procedure   AdapterDataChanged(const AChange: TAdapterChangeEvent; const AData: Variant);
  end;

  IFlexListAdapter = interface
  ['{BF18BBE2-C395-4F27-ADDC-CC4BDB2318D3}']
    procedure AddListHolder(const AValue: IFlexListAdapterHolder);
    { Removes AValue from the list of interest viewers. Returns the number of
      Holders remaining. }
    function  RemoveListHolder(const AValue: IFlexListAdapterHolder): Integer;
    function  GetCount: Integer;
    { View is a TWincontrol to reuse. the returned value is owned and will be
      freed by the ListHolder that called GetView }
    function  GetView(const View: TObject; const AIndex: Integer): TObject;
    function  GetObject(const AIndex: Integer): TObject;

    procedure SetData(AData: TObject; AOwns: Boolean);

    procedure Free; // so we can free the adapter when we are done with it
  end;

  TFlexListAdapterHolderList = specialize TFPGList<IFlexListAdapterHolder>;

  TFlexGetViewEvent = function (const View: TObject; const AIndex: Integer): TObject of object;

  { TFlexBaseAdapter }

  TFlexBaseAdapter =  class(IFlexListAdapter)
  private
    FHolders: TFlexListAdapterHolderList;
    FIsDestroying: Boolean;
    FOnGetView: TFlexGetViewEvent;
    FOwnsData: Boolean;
    FData: TObject;
    procedure   AddListHolder(const AValue: IFlexListAdapterHolder);
    function    RemoveListHolder(const AValue: IFlexListAdapterHolder): Integer;
  protected
    procedure   DoEvent(AEvent: TAdapterChangeEvent; AData: Variant);
    procedure   SetData(AData: TObject; AOwns: Boolean); virtual;
    function    GetCount: Integer; virtual; abstract;
    function    GetView(const View: TObject; const AIndex: Integer): TObject; virtual;
    function    GetObject(const AIndex: Integer): TObject; virtual;
    property    OwnsData: Boolean read FOwnsData;
    property    Data: TObject read FData;
  public
    constructor Create(AData: TObject; AOwnsData: Boolean); virtual;
    destructor  Destroy; override;
    property    OnGetView: TFlexGetViewEvent read FOnGetView write FOnGetView;
    procedure Free;
  end;

  { TFlexViewListEntry }

  TFlexViewListEntry = class(TObject)
  private
    FData: TObject;
    FIndex: Integer;
    FView: TObject;
    function GetTop: Integer;
    function GetHeight: Integer;
    procedure SetTop(AValue: Integer);
  published
    property    View: TObject read FView write FView;
    property    Data: TObject read FData write FData;
    property    Index: Integer read FIndex write FIndex;
    property    Height: Integer read GetHeight;
    property    Top: Integer read GetTop write SetTop;
  public
    constructor Create(AView: TObject; AData: TObject; AIndex: Integer);
    destructor  Destroy; override;
  end;


  TFlexViewListEntryList = specialize TFPGObjectList<TFlexViewListEntry>;

implementation

uses
  typinfo;

{ TFlexBaseAdapter }

procedure TFlexBaseAdapter.AddListHolder(const AValue: IFlexListAdapterHolder);
begin
  if FHolders.IndexOf(AValue) = -1 then
    FHolders.Add(AValue);
  AValue.AdapterDataChanged(acAttach, False);
end;

function TFlexBaseAdapter.RemoveListHolder(const AValue: IFlexListAdapterHolder): Integer;
begin
  FHolders.Remove(AValue);
  Result := FHolders.Count; // if this is zero then the holder will free this adapter
  AValue.AdapterDataChanged(acDetach, False);
end;

procedure TFlexBaseAdapter.DoEvent(AEvent: TAdapterChangeEvent; AData: Variant);
var
  I : IFlexListAdapterHolder;
begin
  try
    for IFlexListAdapterHolder(I) in FHolders do
      I.AdapterDataChanged(AEvent, AData);
  finally
  end;
end;

procedure TFlexBaseAdapter.SetData(AData: TObject; AOwns: Boolean);
begin
  if Assigned(FData) and FOwnsData then
    FreeAndNil(FData);
  FData := AData;
  FOwnsData:=AOwns;

  DoEvent(acRebuild, True);
end;

function TFlexBaseAdapter.GetView(const View: TObject; const AIndex: Integer): TObject;
begin
  if Assigned(FOnGetView) then
    Result := FOnGetView(View, AIndex)
  else
    Result := nil;
end;

function TFlexBaseAdapter.GetObject(const AIndex: Integer): TObject;
begin
  Result := nil;
end;

constructor TFlexBaseAdapter.Create(AData: TObject; AOwnsData: Boolean);
begin
  FHolders := TFlexListAdapterHolderList.Create;
  SetData(AData, AOwnsData);
end;

destructor TFlexBaseAdapter.Destroy;
begin
  FIsDestroying:= True;
  if FOwnsData and Assigned(FData) then
    FreeAndNil(FData);
 // notify all interested observers we are going away.
 DoEvent(acDetach, nil);
 FHolders.Free;
end;

procedure TFlexBaseAdapter.Free;
begin
  if not FIsDestroying then
    inherited Free;
end;

{ TFlexViewListEntry }

function TFlexViewListEntry.GetTop: Integer;
begin
  if FView = nil then
    Result := 0
  else
    Result := GetPropValue(FView, 'Top', False);
end;

function TFlexViewListEntry.GetHeight: Integer;
begin
  if FView = nil then
    Result := 0
  else
    Result := GetPropValue(FView, 'Height', False);
end;

procedure TFlexViewListEntry.SetTop(AValue: Integer);
begin
  SetPropValue(View, 'Top', AValue);
end;

constructor TFlexViewListEntry.Create(AView: TObject; AData: TObject;
  AIndex: Integer);
begin
  FView := AView;
  FData := AData;
  FIndex:= AIndex;
end;

destructor TFlexViewListEntry.Destroy;
begin
  inherited Destroy;
  View.Free;
end;




end.

