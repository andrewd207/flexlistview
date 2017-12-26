{
    This unit is part of the flexlistview component.

    Copyright (c) 2017 by Andrew Haines.

    See the file COPYING.modifiedLGPL, included in this distribution.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

    Description:
      This is the base adapter class which are not dependant on any gui
      components specifically. Set TtiListAdapter.OnGetView to supply the gui
      widget which will display the data. Or subclass it for further
      customization.

      TtiListAdapter implements IFlexListAdapter directly and descends from
      TtiObject.
}
unit FlexTIOPFadapter;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  FlexListViewBase, tiObject, Controls, tiModelMediator;

type

  { TtiListAdapter }

  TtiListAdapter = class(TtiObject, IFlexListAdapter)
  private
    FHolders: TFlexListAdapterHolderList;
    FMediator: TtiModelMediator;
    FOnGetView: TFlexGetViewEvent;
    FList: TtiObjectList;
    procedure   SetMediator(AValue: TtiModelMediator);
  protected
    procedure   DoEvent(AEvent: TAdapterChangeEvent; AData: Variant);
    procedure   AddListHolder(const AValue: IFlexListAdapterHolder);
    function    RemoveListHolder(const AValue: IFlexListAdapterHolder): Integer;
    function    GetView(const View: TObject; const AIndex: Integer): TObject; virtual;
    function    GetObject(const AIndex: Integer): TObject; virtual;
    function    GetCount: Integer;
    procedure   SetData(AData: TObject; AOwns: Boolean);
    property    List: TtiObjectList read FList;
    procedure   Update(ASubject: TtiObject; AOperation: TNotifyOperation;
                   AData: TtiObject); overload; override;
  public
    constructor CreateNew(const ADatabaseName: string=''; const APersistenceLayerName: string=''); overload; override;

    destructor  Destroy; override;
    property    Mediator: TtiModelMediator read FMediator write SetMediator;
    property    OnGetView: TFlexGetViewEvent read FOnGetView write FOnGetView;
  end;

implementation

{ TtiListAdapter }

procedure TtiListAdapter.SetMediator(AValue: TtiModelMediator);
begin
  if FMediator=AValue then Exit;
  FMediator:=AValue;
end;

procedure TtiListAdapter.DoEvent(AEvent: TAdapterChangeEvent; AData: Variant);
var
  I : IFlexListAdapterHolder;
begin
  try
    for IFlexListAdapterHolder(I) in FHolders do
      I.AdapterDataChanged(AEvent, AData);
  finally
  end;
end;

procedure TtiListAdapter.AddListHolder(const AValue: IFlexListAdapterHolder);
begin
  if FHolders.IndexOf(AValue) = -1 then
    FHolders.Add(AValue);
  AValue.AdapterDataChanged(acAttach, False);
end;

function TtiListAdapter.RemoveListHolder(const AValue: IFlexListAdapterHolder): Integer;
begin
  FHolders.Remove(AValue);
  Result := FHolders.Count; // if this is zero then the holder may free this adapter
  AValue.AdapterDataChanged(acDetach, False);
end;

function TtiListAdapter.GetView(const View: TObject; const AIndex: Integer): TObject;
begin
  if Assigned(FOnGetView) then
    Result := FOnGetView(View, AIndex)
  else
    Result := nil;
end;

function TtiListAdapter.GetObject(const AIndex: Integer): TObject;
begin
  Result := List.Items[AIndex];
end;

function TtiListAdapter.GetCount: Integer;
begin
  List.Count;
end;

procedure TtiListAdapter.SetData(AData: TObject; AOwns: Boolean);
begin
  if Assigned(AData) and not AData.InheritsFrom(TtiObjectList) then
    raise Exception.Create(Self.ClassName + 'SetData must be TtiObjectList');

  if Assigned(List) then
    List.DetachObserver(Self);

  FList := AData as TtiObjectList;

  if Assigned(List) then
    List.AttachObserver(Self);

  FMediator.Subject := List;

  DoEvent(acRebuild, nil);
end;

procedure TtiListAdapter.Update(ASubject: TtiObject;
  AOperation: TNotifyOperation; AData: TtiObject);
begin
  inherited Update(ASubject, AOperation, AData);
  case AOperation of
    noAddItem: DoEvent(acGrow, nil);
    noDeleteItem: DoEvent(acShrink, nil);
    noChanged: DoEvent(acRebuild, nil);
  end;
end;

constructor TtiListAdapter.CreateNew(const ADatabaseName: string;
  const APersistenceLayerName: string);
begin
  inherited CreateNew(ADatabaseName, APersistenceLayerName);
  FHolders := TFlexListAdapterHolderList.Create;
  FMediator := TtiModelMediator.Create(nil);
end;


destructor TtiListAdapter.Destroy;
begin
  inherited Destroy;
  FMediator.Free;
  FHolders.Free;
end;

end.

