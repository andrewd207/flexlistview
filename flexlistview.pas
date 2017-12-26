unit FlexListView;
{ This is heavily 'inspired' by the android ListView which is awesome.}

{$mode objfpc}{$H+}
{$interfaces corba}

interface

uses
  Classes, SysUtils, Controls, StdCtrls, fgl, variants, LMessages, FlexListViewBase;

type

  { TFlexStringsAdapter }

  TFlexStringsAdapter = class(TFlexBaseAdapter)
    FOwnsStrings: Boolean;
  private
    function GetStrings: TStrings;
  private
    property Strings: TStrings read GetStrings;
  protected
    function    GetCount: Integer; override;
    function    GetView(const View: TObject; const AIndex: Integer): TObject; override;
    function    GetObject(const AIndex: Integer): TObject; override;
  public
    constructor Create(AStrings: TStrings; AOwnsStrings: Boolean = True); virtual; reintroduce;
  end;

  { TFlexListView }

  TFlexListView = class(TCustomControl, IFlexListAdapterHolder)
  private
    FViews: TFlexViewListEntryList;
    FUnusedViews: TFlexViewListEntryList;
    FAdapter: IFlexListAdapter;
    FScrollBar: TScrollBar;
    FScrolledPosition: Integer;
    FTopItemOffset: Integer;
    FSelectedIndex: Integer;
    FFirstVisible: Integer;
    FLastVisible: Integer;
    FFixItemHeightQueued: Boolean;
    procedure   DoFixItemHeight;
    procedure   FixItemHeight(AData: PtrInt);
    procedure   AdapterItemResize(Sender: TObject);
    procedure   ScrollViews(Sender: TObject; ScrollCode: TScrollCode; var ScrollPos: Integer);
    procedure   SetAdapter(AValue: IFlexListAdapter);
    procedure   UpdateViews(AHeight: Integer);
    function    GetCount: Integer;
    function    GetItemHeight: Integer;
    function    GetAvailableView: TFlexViewListEntry;
    procedure   CalculateNeededItems(out AStartStart, AStartEnd, AEndStart, AEndEnd: Integer; AHeight: Integer);
    function    GetView(AIndex: Integer; ATop: Integer): TFlexViewListEntry;
    procedure   ClearViews;
    procedure   HideView(AView: TFlexViewListEntry);
    procedure   HideAllViews;
  protected
    procedure   WMSize(var Message: TLMSize); message LM_SIZE;
    procedure   WMMouseWheel(var Message: TLMMouseEvent); message LM_MOUSEWHEEL;

  private
    // IFlexListAdapter
    procedure   AdapterDataChanged(const AChange: TAdapterChangeEvent; const AData: Variant);

  published
    property    Align;
    property    Adapter: IFlexListAdapter read FAdapter write SetAdapter;
  public
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;
  end;

implementation
uses
  Forms;


{ TFlexStringsAdapter }

function TFlexStringsAdapter.GetStrings: TStrings;
begin
  Result := Data as TStrings;
end;

function TFlexStringsAdapter.GetCount: Integer;
begin
  Result := Strings.Count;
end;

function TFlexStringsAdapter.GetView(const View: TObject; const AIndex: Integer
  ): TObject;
var
  lLabel: TLabel absolute Result;
begin
  if not Assigned(View) then
  begin
    lLabel := TLabel.Create(nil);
  end
  else
    lLabel := TLabel(View);

  lLabel.Caption := Strings[AIndex];
end;

function TFlexStringsAdapter.GetObject(const AIndex: Integer): TObject;
begin
  Result := Strings.Objects[AIndex];
end;


constructor TFlexStringsAdapter.Create(AStrings: TStrings; AOwnsStrings: Boolean);
begin
  inherited Create(AStrings, AOwnsStrings);
end;

{ TFlexListView }

procedure TFlexListView.SetAdapter(AValue: IFlexListAdapter);
begin
  if FAdapter=AValue then Exit;

  if Assigned(FAdapter) and (FAdapter.RemoveListHolder(Self as IFlexListAdapterHolder) = 0) then
    FAdapter.Free;

  FAdapter:=AValue;
  if Assigned(FAdapter) then
    FAdapter.AddListHolder(Self as IFlexListAdapterHolder);
end;

procedure TFlexListView.ScrollViews(Sender: TObject; ScrollCode: TScrollCode;
  var ScrollPos: Integer);
var
  lDelta:Integer;
  lItemHeight, i: Integer;
  lView: TFlexViewListEntry;
begin
  WriteLn(ScrollCode, ' ', ScrollPos);
  //if ScrollCode = scTrack then exit;
  lDelta:=FScrolledPosition-ScrollPos;
  FScrolledPosition:=ScrollPos;

  if lDelta = 0 then
    Exit;

  lItemHeight:=GetItemHeight;
  FTopItemOffset := -(ScrollPos mod lItemHeight)  ;
  if +(lDelta) > Height then
  begin
    HideAllViews;
  end
  else
  begin
    for i := FViews.Count-1 downto 0 do
    begin
      if FViews.Count > 100 then
        WriteLn('Too many views! ', FViews.Count);

      lView := FViews[i];
      lView.Top := lView.Top + lDelta;

      if lView.Top+lView.Height < 0 then
      begin
        Inc(FFirstVisible);
        HideView(lView);
      end
      else if lView.Top > Height then
      begin
        Dec(FLastVisible);
        HideView(lView);
      end;
    end;
  end;

  FScrollBar.Position:=ScrollPos;

  UpdateViews(Height);
end;

procedure TFlexListView.DoFixItemHeight;
begin
  if not FFixItemHeightQueued then
    Application.QueueAsyncCall(@FixItemHeight, 0);
  FFixItemHeightQueued:=True;
end;

procedure TFlexListView.FixItemHeight(AData: PtrInt);
var
  lTop, i: Integer;
begin
  if GetItemHeight > 0 then
    lTop := -(FScrollBar.Position mod GetItemHeight)
  else
    lTop := 0;
  for i := 0 to FViews.Count-1 do
  begin
    FViews.Items[i].Top:=lTop;
    Inc(lTop, FViews[i].Height);
  end;
  UpdateViews(Height);

  FFixItemHeightQueued:=False;
end;

procedure TFlexListView.AdapterItemResize(Sender: TObject);
begin
  DoFixItemHeight;
end;

procedure TFlexListView.UpdateViews(AHeight: Integer);
var
  lCount: Integer;
  i: Integer;
  lTop: Integer = 0;
  lScrollMax,
  lStartLow,
  lStartHigh,
  lEndLow,
  lEndHigh,
  lItemHeight: Integer;
begin
  lCount:=GetCount;
  lItemHeight := GetItemHeight;
  FScrollBar.Enabled:=lCount > 0;

  if not Assigned(Adapter) then
    Exit; // ==>

  CalculateNeededItems(lStartLow, lStartHigh, lEndLow, lEndHigh, AHeight);

  for i := lStartHigh downto lStartLow do
  begin
    if FViews.Count > 0 then
      lTop := FViews[0].Top-lItemHeight
    else
      lTop := 0; // also we need to check for scrollbar if item partly visble only
    GetView(i, lTop);
  end;

  if lStartHigh > -1 then
    FFirstVisible:=lStartLow;

  for i := lEndLow to lEndHigh do
  begin
    if FViews.Count > 0 then
      lTop := FViews[FViews.Count-1].Top+FViews[FViews.Count-1].Height//-(lItemHeight * (lStartHigh-lStartLow))
    else
    lTop := 0; // also we need to check for scrollbar if item part visble only

    GetView(i, lTop);
    //Inc(lTop,lItemHeight);
  end;

  if lEndHigh > -1 then
  begin
    FLastVisible:=lEndHigh;
    if FFirstVisible = -1 then
      FFirstVisible := lEndLow;
  end;

  lScrollMax:=lCount*lItemHeight;
    if lScrollMax < 0 then
      lScrollMax:=0;
    if FScrollBar.Max <> lScrollMax then
      FScrollBar.Max:=lScrollMax;

  FScrollBar.PageSize:=AHeight;
end;

procedure TFlexListView.WMSize(var Message: TLMSize);
begin
  FixItemHeight(0);
  WriteLn('Resizing ', GetCount);
end;

procedure TFlexListView.WMMouseWheel(var Message: TLMMouseEvent);
begin
  //WriteLn('mouseWheel ', Message.WheelDelta);
  //FScrollBar.;
  FScrollBar.ScrollBy_WS(0, Message.WheelDelta);

end;

function TFlexListView.GetCount: Integer;
begin
  if Assigned(FAdapter) then
    Result := FAdapter.GetCount
  else
    Result := 0;
end;

function TFlexListView.GetItemHeight: Integer;
var
  lView: TFlexViewListEntry;
begin
  Result := 0;
  if FViews.Count>0 then
    Result := FViews[0].Height
  else if FUnusedViews.Count>0 then
    Result := FUnusedViews[0].Height
  else if GetCount > 0 then
  begin
    // grab an item so that we can get it's height
    lView := GetView(0,0);
    Result := lView.Height;
    FViews.Delete(0);
    FUnusedViews.Add(lView);
  end;
end;

function TFlexListView.GetAvailableView: TFlexViewListEntry;
begin
  Result := nil;
  if FUnusedViews.Count > 0 then
  begin
    Result := FUnusedViews[FUnusedViews.Count-1];
    FUnusedViews.Delete(FUnusedViews.Count-1);
  end;
end;

procedure TFlexListView.CalculateNeededItems(out AStartStart, AStartEnd,
  AEndStart, AEndEnd: Integer; AHeight: Integer);
var
  lItemHeight, lFirst, lLast: Integer;
begin
  lItemHeight:=GetItemHeight;

  AStartEnd := -1;
  AEndEnd := -1;
  AStartStart := 0;
  AEndStart := 0;

  if lItemHeight = 0 then
    Exit;

  if FScrollBar.Position = 0 then
    lFirst:=0
  else
    lFirst := FScrollBar.Position div lItemHeight;

  if lFirst < FFirstVisible then
  begin
    AStartStart := lFirst;
    AStartEnd := FFirstVisible-1;
    if AStartEnd < 0 then
      AStartEnd:=0;
  end;

  lLast := lFirst + (AHeight div lItemHeight);
  if lLast > FLastVisible then
  begin
    AEndStart := FLastVisible+1;
    AEndEnd:=lLast;
  end;

  //WriteLn(Format('%d-%d %d-%d  h=%d itemheight=%d',[AStartStart, AStartEnd, AEndStart, AEndEnd, AHeight, lItemHeight]) );

end;

function TFlexListView.GetView(AIndex: Integer; ATop: Integer): TFlexViewListEntry;
var
  lView: TWinControl;
  lViewEntry: TFlexViewListEntry;
  i: Integer;
begin
  Result := nil;
  if AIndex >= Adapter.GetCount then
    Exit;// ==>

  lViewEntry := GetAvailableView;
  if Assigned(lViewEntry) then
    lView := TWinControl(lViewEntry.View)
  else
    lView := nil;

  lView := TWinControl(Adapter.GetView(lView, AIndex));
  // if the adapter didn't use the view we gave it then free it.
  if Assigned(lViewEntry) and (lViewEntry.View <> lView) then
  begin
    lViewEntry.View.Free;
    lViewEntry.View := lView;
    lViewEntry.Data := Adapter.GetObject(AIndex);
    lView.AddHandlerOnResize(@AdapterItemResize);
    TFlexListView(lView).SetDesigning(True);
  end;

  if not Assigned(lViewEntry) then
  begin
    lViewEntry := TFlexViewListEntry.Create(lView, Adapter.GetObject(AIndex), AIndex);
    lView.AddHandlerOnResize(@AdapterItemResize);
    //lView.ComponentState := lView.ComponentState + [csDesigning];
    TFlexListView(lView).SetDesigning(True);
  end;

  lView.Parent := Self;
  lView.Top := ATop;
  lView.Left := 0;
  lView.Width:=Width-FScrollBar.Width;
  lView.Visible:=True;
  Result := lViewEntry;

  FViews.Remove(lViewEntry);
  // insert items in the order they will show.

  for i := 0 to FViews.Count-1 do
  begin
    if lView.Top < FViews[i].Top then
    begin
      FViews.Insert(i, lViewEntry);
      lViewEntry := nil;
      Break;
    end;
  end;
  // add to the end of the list if it's not added yet
  if Assigned(lViewEntry) then
    FViews.Add(lViewEntry);
end;

procedure TFlexListView.ClearViews;
var
  i: Integer;
begin
  for i := 0 to FViews.Count-1 do
    FViews[i].Free;

  for i := 0 to FUnusedViews.Count-1 do
    FUnusedViews[i].Free;

  FViews.Clear;
  FUnusedViews.Clear;
end;

procedure TFlexListView.HideView(AView: TFlexViewListEntry);
begin
  if FViews.Remove(AView) = -1 then
  begin
    WriteLn('AView not found in visible list but asked to remove!');
  end;
  if FUnusedViews.IndexOf(AView) = -1 then
    FUnusedViews.Add(AView);
  //AView.Visible:=False;

  TWinControl(AView.View).Parent.RemoveControl(AView.View as TWinControl);
  AView.Top := -1;
  //AView.Parent := nil;
end;

procedure TFlexListView.HideAllViews;
var
  i: Integer;
begin
  for i := FViews.Count-1 downto 0 do
    HideView(FViews[i]);
  WriteLn('Cleared Views. ', FViews.Count);
  FFirstVisible:=-1;
  FLastVisible:=-1;
end;

procedure TFlexListView.AdapterDataChanged(const AChange: TAdapterChangeEvent;
  const AData: Variant);
begin
  case AChange of
    acAttach, acGrow: UpdateViews(Height);
    acDetach: ClearViews;
    acRebuild:
      begin
        HideAllViews;
        UpdateViews(Height);
      end;
  end;
end;

constructor TFlexListView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FScrollBar := TScrollBar.Create(Self);
  FScrollBar.Parent := Self;
  FScrollBar.Kind:=sbVertical;
  FScrollBar.Anchors := [akTop, akRight, akBottom];
  FScrollBar.AnchorSideTop.Control := Self;
  FScrollBar.AnchorSideTop.Side:=asrTop;
  FScrollBar.AnchorSideRight.Control := Self;
  FScrollBar.AnchorSideRight.Side:=asrRight;
  FScrollBar.AnchorSideBottom.Control:=Self;
  FScrollBar.AnchorSideBottom.Side:=asrBottom;
  FScrollBar.OnScroll:=@ScrollViews;
  FViews := TFlexViewListEntryList.Create(False);
  FUnusedViews := TFlexViewListEntryList.Create(False);
  FFirstVisible:=0;
  FLastVisible:=-1;
end;

destructor TFlexListView.Destroy;
begin
  inherited Destroy;
  FViews.FreeObjects:=True;
  FUnusedViews.FreeObjects:=True;
  FViews.Free;
  FUnusedViews.Free;
end;

end.

