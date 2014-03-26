/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#include <Vision/Runtime/Framework/VisionApp/Modules/VDefaultMenu.hpp>
#include <Vision/Runtime/Framework/VisionApp/VAppImpl.hpp>

#include <Vision/Runtime/Framework/VisionApp/Modules/VExitHandler.hpp>

VDefaultMenuListControlItem* FindItemRecursive(VDefaultMenuListControlItem* pParent, const char* szItemName)
{
  if (strcmp(pParent->GetText(), szItemName) == 0)
    return pParent;

  VRefCountedCollection<VDefaultMenuListControlItem>& items = pParent->GetChildren();
  for (int i=0; i<items.Count(); ++i)
  {
    VDefaultMenuListControlItem* pItem = FindItemRecursive(items.GetAt(i), szItemName);
    if (pItem != NULL)
      return pItem;
  }

  return NULL;
}

int CompareItemOrder(const void* pArg0, const void* pArg1)
{
  const VDefaultMenuListControlItem* p0 = *reinterpret_cast<const VDefaultMenuListControlItem* const*>(pArg0);
  const VDefaultMenuListControlItem* p1 = *reinterpret_cast<const VDefaultMenuListControlItem* const*>(pArg1);
  
  int iValue = p0->GetSortingKey() - p1->GetSortingKey();
  if (iValue != 0)
    return iValue;
  else
    return (pArg0 < pArg1) ? -1 : 1;
}

// VAppDefaultMenuListControlItem

float VDefaultMenuListControlItem::m_fSpacing = 2.0f;

VDefaultMenuListControlItem::VDefaultMenuListControlItem()
  : VListControlItem()
  , m_bCheckable(true)
  , m_bActive(false)
  , m_uiSortingKey(0)
  , m_pParent(NULL)
  , m_spGroupIcon(NULL)
  , m_spActiveIcon(NULL)
  , m_pCallback(NULL)
  , m_pCallbackData(NULL)
{

}

VDefaultMenuListControlItem::VDefaultMenuListControlItem(const char* szText, unsigned int uiSortingKey, bool bCheckable, bool bIsChecked)
  : VListControlItem(szText)
  , m_bCheckable(bCheckable)
  , m_bActive(m_bCheckable && bIsChecked)
  , m_uiSortingKey(uiSortingKey)
  , m_pParent(NULL)
  , m_spGroupIcon(NULL)
  , m_spActiveIcon(NULL)
  , m_pCallback(NULL)
  , m_pCallbackData(NULL)
{

}

VDefaultMenuListControlItem::~VDefaultMenuListControlItem()
{
  m_spGroupIcon = NULL;
  m_spActiveIcon = NULL;

  m_children.Clear();

  if (m_pCallback)
  {
    VAppMenuDataObject data(m_pCallback, VAppMenuDataObject::TYPE_DELETE, -1);
    m_pCallback->TriggerCallbacks(&data);
  }

  V_SAFE_DELETE(m_pCallbackData);
  V_SAFE_DELETE(m_pCallback);
}

void VDefaultMenuListControlItem::OnPaint(VGraphicsInfo &Graphics, const VItemRenderInfo &parentState)
{
  if (IsClipped())
    return;

  const VSimpleRenderState_t iProperties = VGUIManager::DefaultGUIRenderState();
  VItemRenderInfo thisState(parentState, this, 1.0f);
  VRectanglef rect = thisState.m_pWindow->GetBoundingBox();

  // Item/Group background rect
  bool bHasChildren = HasChildren();
  if ((strcmp(GetText(), "..") != 0))
  {
    hkvVec2 topLeft = rect.m_vMin + hkvVec2(m_fSpacing, GetIndex() == 0 ? m_fSpacing : 0);
    hkvVec2 bottomRight = rect.m_vMax - hkvVec2(m_fSpacing, m_fSpacing);

    if (bHasChildren)
      Graphics.Renderer.DrawSolidQuad(topLeft, bottomRight, VAppMenuColors::GetColor(VAppMenuColors::COLOR_LIST_GROUP_BG), iProperties);
    else
      Graphics.Renderer.DrawSolidQuad(topLeft, bottomRight, VAppMenuColors::GetColor(VAppMenuColors::COLOR_LIST_ITEM_BG), iProperties);
  }

  // Item itself (text, etc.)
  VListControlItem::OnPaint(Graphics, parentState);

  VASSERT(GetParent() != NULL && GetParent()->GetParent() != NULL);
  const float fScale = ((VDefaultMenuDialog*)GetParent()->GetParent())->GetScale();
  const float fImageScale = fScale * (32.0f / (float)m_spGroupIcon->GetTextureWidth()) * 0.25f;

  // Group/Checkable icon
  if (bHasChildren && (m_spGroupIcon != NULL))
  {
    const hkvVec2 offset((float)m_spGroupIcon->GetTextureWidth()*fImageScale, (float)m_spGroupIcon->GetTextureHeight()*fImageScale);
    hkvVec2 center(rect.m_vMin.x + rect.GetSizeX() - offset.x - 5*fScale, rect.m_vMin.y + rect.GetSizeY() * 0.5f);
    Graphics.Renderer.DrawTexturedQuad(center - offset, center + offset, m_spGroupIcon, hkvVec2(0.0f, 0.0f), hkvVec2(1.0f, 1.0f), V_RGBA_WHITE, iProperties);
  }
  else if (m_bActive && m_bCheckable)
  {
    const hkvVec2 offset((float)m_spActiveIcon->GetTextureWidth()*fImageScale, (float)m_spActiveIcon->GetTextureHeight()*fImageScale);
    hkvVec2 center(rect.m_vMin.x - offset.x + 15*fScale, rect.m_vMin.y + rect.GetSizeY() * 0.5f);
    Graphics.Renderer.DrawTexturedQuad(center - offset, center + offset, m_spActiveIcon, hkvVec2(0.0f, 0.0f), hkvVec2(1.0f, 1.0f), V_RGBA_WHITE, iProperties);
  }
}

void VDefaultMenuListControlItem::AddChild(VDefaultMenuListControlItem* pChild)
{
  m_children.Add(pChild);
  pChild->m_pParent = this;
}

VisCallback_cl* VDefaultMenuListControlItem::CreateCallback(int iAction)
{
  m_pCallback = new VisCallback_cl();
  m_pCallbackData = new VAppMenuDataObject(m_pCallback, VAppMenuDataObject::TYPE_TRIGGER, iAction);
  return m_pCallback;
}

void VDefaultMenuListControlItem::TriggerCallback()
{
  if (m_pCallback == NULL)
    return;

  bool bActive = m_bActive;

  // Disable all items (neighbors) with the same parent if checkable is used
  VDefaultMenuListControlItem* pParent = GetParentItem();
  if (!pParent->m_bCheckable)
  {
    VRefCountedCollection<VDefaultMenuListControlItem>& children = pParent->GetChildren();
    for (int i=0; i<children.Count(); ++i)
      children.GetAt(i)->m_bActive = false;
  }

  m_pCallback->TriggerCallbacks(m_pCallbackData);
  m_bActive = !bActive;
}

// VAppDefaultMenuDialog

float VDefaultMenuDialog::s_fBorderWidth = 5.0f;
float VDefaultMenuDialog::s_fFadeTime = 0.15f;
float VDefaultMenuDialog::s_fFontScale = 0.76f;

VDefaultMenuDialog::VDefaultMenuDialog()
  : m_state(STATE_NONE)
  , m_followUpState(STATE_NONE)
  , m_fTimer(0.0f)
  , m_pFutureItem(NULL)
  , m_pLabel(NULL)
  , m_pListControl(NULL)
  , m_fScale(1.0f)
  , m_fOffsetY(0.0f)
  , m_spItemGroup(NULL)
  , m_spItemActive(NULL)
  , m_bIsDirty(true)
{
  SetPosition(0.0f, m_fOffsetY);
  m_iBackColor = VAppMenuColors::GetColor(VAppMenuColors::COLOR_DIALOG_BG);

  m_fScale = VAppHelper::GetUIScalingFactor();

  s_fBorderWidth *= m_fScale;

  m_spFont = Vision::Fonts.LoadFont("Fonts/OpenSans_22.fnt");

  m_pLabel = new VTextLabel();
  m_pLabel->SetSize(400.0f, 32.0f*m_fScale);
  m_pLabel->SetPosition(s_fBorderWidth + 5.0f*m_fScale, s_fBorderWidth);
  m_pLabel->Text().SetFont(m_spFont);
  m_pLabel->Text().m_States[VWindowBase::NORMAL].SetColor(VAppMenuColors::GetColor(VAppMenuColors::COLOR_TEXT));
  m_pLabel->Text().SetScaling(s_fFontScale*m_fScale);
  m_pLabel->Text().SetVerticalAlignment(VisFont_cl::ALIGN_CENTER);
  AddControl(m_pLabel);

  VSliderControl* pScrollbar = new VSliderControl();
  pScrollbar->SetSize(16.0f*m_fScale, 1.0f);
  pScrollbar->SetSliderRange(0, 100, 0);
  pScrollbar->Frame().m_States[VWindowBase::NORMAL].SetTexture(Vision::TextureManager.Load2DTexture("\\Textures\\vapp_scrollbar.dds"));
  pScrollbar->GetSlider()->Images().m_States[VWindowBase::NORMAL].SetTexture(Vision::TextureManager.Load2DTexture("\\Textures\\vapp_slider.dds"));
  pScrollbar->GetSlider()->Images().m_States[VWindowBase::NORMAL].SetTextureRange(VRectanglef(-m_fScale*0.5f, -m_fScale*0.5f, m_fScale*0.5f, m_fScale*0.5f));
  pScrollbar->GetSlider()->OnBuildFinished();

  m_pListControl = new VListControl();
  m_pListControl->SetPosition(s_fBorderWidth, s_fBorderWidth + m_pLabel->GetSize().y);
  m_pListControl->SetBackgroundColor(VAppMenuColors::GetColor(VAppMenuColors::COLOR_LIST_CONTROL_BG));
  m_pListControl->SetScrollBar(pScrollbar);
  AddControl(m_pListControl);

  m_spRoot = new VDefaultMenuListControlItem("ROOT", 0, true, false);
  m_spBack = new VDefaultMenuListControlItem("..", 0, true, false);
  m_spCurrent = m_spRoot;

  m_spItemGroup = Vision::TextureManager.Load2DTexture("\\Textures\\vapp_group_icon.dds");
  m_spItemActive = Vision::TextureManager.Load2DTexture("\\Textures\\vapp_active_icon.dds");

  m_pCloseButton = new VStyledButton("X", false, m_spFont, m_fScale, hkvMath::ceil(1.5f * m_fScale), s_fFontScale*m_fScale);
  m_pCloseButton->SetSize(m_fScale*90.0f, m_pLabel->GetSize().y * 1.0f - m_fScale*2.0f);
  m_pCloseButton->SetOrder(2);

  AddControl(m_pCloseButton);
}

VDefaultMenuDialog::~VDefaultMenuDialog()
{
  m_spRoot = NULL;
  m_spBack = NULL;
  m_spCurrent = NULL;

  m_spItemGroup = NULL;
  m_spItemActive = NULL;

  m_spFont = NULL;
}

void VDefaultMenuDialog::Update(float fDeltaTime)
{
  if (m_state == STATE_NONE)
  {
    RefreshLayout();
    return;
  }

  // Update animation if there is one in progress
  if (m_fTimer > 0.0f)
  {
    m_fTimer -= fDeltaTime;

    const float fX = hkvMath::Min(1.0f, 1.0f - m_fTimer / s_fFadeTime);
    float fDelta = hkvMath::sinRad(hkvMath::pi()*fX - hkvMath::pi()*0.5f)*0.5f + 0.5f;
    if (m_state == STATE_FADE_IN)
      SetPosition((fDelta - 1.0f)*GetSize().x, m_fOffsetY);
    else
      SetPosition(-fDelta*GetSize().x, m_fOffsetY);
  }
  else
  {
    m_fTimer = 0.0f;
    m_state = STATE_NONE;

    // If animation just finished there might be a follow up state which needs
    // to be processed accordingly
    if (m_followUpState == STATE_HIDE)
    {
      Reset();
    }
    else if (m_followUpState == STATE_OPEN)
    {
      VASSERT(m_pFutureItem != NULL);
      m_spCurrent = m_pFutureItem;
      RequestRefresh();
      DoFadeIn();
    }
    else if (m_followUpState == STATE_BACK)
    {
      BackToParentGroup();
      DoFadeIn();
    }
  }
}

VDefaultMenuListControlItem* VDefaultMenuDialog::AddGroup(const char* szGroupName, VDefaultMenuListControlItem* pParent, unsigned int uiSortingKey, bool bMultiSelect)
{
  if (pParent == NULL)
    pParent = m_spRoot.GetPtr();

  VDefaultMenuListControlItem* pItem = new VDefaultMenuListControlItem(szGroupName, uiSortingKey, bMultiSelect, false);
  pParent->AddChild(pItem);
  return pItem;
}

VisCallback_cl* VDefaultMenuDialog::AddItem(const VAppMenuItem& item, VDefaultMenuListControlItem* pParent)
{
  if (pParent == NULL)
    pParent = m_spRoot.GetPtr();

  VDefaultMenuListControlItem* pItem = new VDefaultMenuListControlItem(item.m_sItemName, item.m_uiSortingKey, item.m_bCheckable, item.m_bInitCheckState);
  pParent->AddChild(pItem);
  return pItem->CreateCallback(item.m_iAction);
}

VDefaultMenuListControlItem* VDefaultMenuDialog::FindItem(const char* szItemName)
{
  VDefaultMenuListControlItem* pResult = FindItemRecursive(m_spRoot, szItemName);
  return pResult;
}

void VDefaultMenuDialog::OnItemClicked(VMenuEventDataObject *pEvent)
{
  VDialog::OnItemClicked(pEvent);

  if (pEvent->m_pItem == m_pListControl)
  {
    VGUIUserInfo_t* pUser = GetContext()->GetUser(VGUIUserInfo_t::GUIUser0);
    VDefaultMenuListControlItem* pItem = (VDefaultMenuListControlItem*)m_pListControl->GetItemAt(*pUser, pEvent->m_vMousePos);
    if (pItem != NULL && pItem->IsSelected())
      ProcessItemEvent(pItem);
  }
  else if (pEvent->m_pItem == m_pCloseButton)
  {
    DoFadeOut(STATE_HIDE);
  }
}

void VDefaultMenuDialog::SelectPreviousItem()
{
  assert(m_pListControl != NULL);

  int iIndex = m_pListControl->GetSelectionIndex() - 1;
  if (iIndex < 0)
    iIndex = m_pListControl->Items().Count() - 1;

  m_pListControl->SetSelectionIndex(iIndex);
  m_pListControl->EnsureVisible(m_pListControl->GetSelectedItem());
}

void VDefaultMenuDialog::SelectNextItem()
{
  assert(m_pListControl != NULL);

  int iIndex = m_pListControl->GetSelectionIndex() + 1;
  if (iIndex >= m_pListControl->Items().Count())
    iIndex = 0;

  m_pListControl->SetSelectionIndex(iIndex);
  m_pListControl->EnsureVisible(m_pListControl->GetSelectedItem());
}

void VDefaultMenuDialog::TriggerSelectedItem()
{
  int iIndex = m_pListControl->GetSelectionIndex();
  if (iIndex >= 0)
    ProcessItemEvent((VDefaultMenuListControlItem*)m_pListControl->GetSelectedItem());
}

void VDefaultMenuDialog::BackToParentGroup()
{
  if (m_spCurrent == m_spRoot)
    return;

  // Backup for selection
  VDefaultMenuListControlItem* pItem = m_spCurrent;

  m_spCurrent = m_spCurrent->GetParentItem();

  RequestRefresh();
  RefreshLayout();

  m_pListControl->SetSelection(pItem);
  m_pListControl->EnsureVisible(m_pListControl->GetSelectedItem());
}

void VDefaultMenuDialog::SwitchToRoot()
{
  if (m_spCurrent == m_spRoot)
    return;

  m_spCurrent = m_spRoot;

  RequestRefresh();
  RefreshLayout();

  m_pListControl->SetSelectionIndex(0);
  m_pListControl->EnsureVisible(m_pListControl->GetSelectedItem());
}

void VDefaultMenuDialog::SwitchToGroup(VDefaultMenuListControlItem* pItem)
{
  if (m_spCurrent == pItem || !pItem->HasChildren())
    return;

  m_spCurrent = pItem;

  RequestRefresh();
  RefreshLayout();

  m_pListControl->SetSelectionIndex(0);
  m_pListControl->EnsureVisible(m_pListControl->GetSelectedItem());
}

bool VDefaultMenuDialog::IsChildOf(const VDefaultMenuListControlItem* pItem, const VDefaultMenuListControlItem* pParent) const
{
  if ((pItem == NULL) || (pItem == m_spRoot))
    return false;

  const VDefaultMenuListControlItem* pCurrent = pItem->GetParentItem();
  while (pCurrent != m_spRoot)
  {
    if (pCurrent == pParent)
      return true;

    pCurrent = pCurrent->GetParentItem();
  }

  return false;
}

void VDefaultMenuDialog::RefreshLayout()
{
  if (!m_bIsDirty)
    return;

  m_pListControl->Reset();

  // Add helper item to go up the hierarchy
  if (m_spCurrent != m_spRoot)
  {
    m_spBack->SetParent(m_spCurrent);
    AddItemToList(m_spBack);
  }

  // Build label text depending on the current position in the hierarchy
  VString sLabelText;
  BuildLabelText(sLabelText);
  m_pLabel->SetText(sLabelText);

  VRectanglef rect;
  m_spFont->GetTextDimension(sLabelText, rect);

  // Helper to determine the required with of the menu
  float fWidth = rect.GetSizeX();
  fWidth += m_pCloseButton->GetSize().x / m_fScale + m_fScale * 16.0f;

  // Add all elements of the current level of the hierarchy
  VRefCountedCollection<VDefaultMenuListControlItem>& items = m_spCurrent->GetChildren();
  qsort(items.GetPtrs(), items.Count(), sizeof(VDefaultMenuListControlItem*), CompareItemOrder);

  for (int i=0; i<items.Count(); ++i)
  {
    VDefaultMenuListControlItem* pItem = items.GetAt(i);
    AddItemToList(pItem);
    m_spFont->GetTextDimension(pItem->GetText(), rect);
    fWidth = hkvMath::Max(fWidth, rect.GetSizeX());
  }

  // Enlarge width so that everything fits
  fWidth *= m_fScale;
  fWidth += s_fBorderWidth*2.0f;
  
  if ((fWidth) > Vision::Video.GetXRes())
    fWidth = (float)Vision::Video.GetXRes();

  // Calculate height depending on the current item count and other important spacing parameters
  const float fSpacing = (m_spCurrent != m_spRoot) ? (float)s_iItemHeight : 0.0f;
  float fHeight = ((float)(items.Count() * s_iItemHeight)+ fSpacing)*m_fScale + s_fBorderWidth*2.0f + m_pLabel->GetSize().y;

  float fSliderWidth = 0.0f;
  if ((fHeight + GetPosition().y) > Vision::Video.GetYRes())
  {
    fSliderWidth = 16.0f*m_fScale;
    fHeight = (float)Vision::Video.GetYRes() - GetPosition().y;
  }

  // Apply...
  SetSize(fWidth, fHeight);
  m_pListControl->SetSize(fWidth - fSliderWidth - s_fBorderWidth*2.0f, fHeight - m_pListControl->GetPosition().y - s_fBorderWidth);

  // Fallback which ensures that there is always an item being selected
  if ((m_pListControl->GetSelectionIndex() < 0) && m_pListControl->Items().Count() > 0)
  {
    m_pListControl->SetSelectionIndex(0);
    m_pListControl->EnsureVisible(m_pListControl->GetSelectedItem());
  }

  // Close button position
  m_pCloseButton->SetPosition(fWidth - fSliderWidth - m_pCloseButton->GetSize().x - s_fBorderWidth, s_fBorderWidth);

  m_bIsDirty = false;
}

void VDefaultMenuDialog::DoFadeIn()
{
  if (m_state != STATE_NONE)
    return;

  RefreshLayout();

  SetPosition(-GetSize().x, m_fOffsetY);
  m_fTimer = s_fFadeTime;
  m_state = STATE_FADE_IN;
  m_followUpState = STATE_NONE;
}

void VDefaultMenuDialog::DoFadeOut(const VDialogState& followUpState)
{
  if ((m_state != STATE_NONE) || (m_spCurrent == m_spRoot && followUpState == STATE_BACK))
    return;

  RefreshLayout();

  SetPosition(0.0f, m_fOffsetY);
  m_fTimer = s_fFadeTime;
  m_state = STATE_FADE_OUT;
  m_followUpState = followUpState;
}

void VDefaultMenuDialog::Reset()
{
  SetPosition(0.0f, m_fOffsetY);
  m_fTimer = 0.0f;
  m_state = STATE_NONE;
  m_followUpState = STATE_NONE;

  if (GetContext()->GetOpenDialogs().Contains(this))
    GetContext()->CloseDialog(this);
  SetVisible(false);

  if (VInputMap::AreInputMapsLocked())
    VInputMap::LockInputMaps(false);
}

void VDefaultMenuDialog::ProcessItemEvent(VDefaultMenuListControlItem* pItem)
{
  if (pItem == NULL)
    return;

  m_pFutureItem = pItem;
  if (pItem == m_spBack)
    DoFadeOut(STATE_BACK);
  else if (pItem->HasChildren())
    DoFadeOut(STATE_OPEN);
  else
    pItem->TriggerCallback();
}

void VDefaultMenuDialog::AddItemToList(VDefaultMenuListControlItem* pItem)
{
  if (pItem == NULL)
    return;

  m_pListControl->AddItem(pItem);
  pItem->m_iCustomHeight = (int)(s_iItemHeight*m_fScale);
  pItem->m_Text.SetFont(m_spFont);
  pItem->m_Text.SetTextOfs(hkvVec2(20.0f*m_fScale, 0.0f));
  pItem->m_Text.m_States[VWindowBase::NORMAL].SetColor(VAppMenuColors::GetColor(VAppMenuColors::COLOR_LIST_ITEM_TEXT_NORMAL));
  pItem->m_Text.m_States[VWindowBase::MOUSEOVER].SetColor(VAppMenuColors::GetColor(VAppMenuColors::COLOR_LIST_ITEM_TEXT_OVER));
  pItem->m_Text.m_States[VWindowBase::SELECTED].SetColor(VAppMenuColors::GetColor(VAppMenuColors::COLOR_LIST_ITEM_TEXT_SELECTED));
  pItem->m_Text.SetScaling(s_fFontScale*m_fScale);
  pItem->m_Text.SetVerticalAlignment(VisFont_cl::ALIGN_CENTER);
  pItem->SetGroupIcon(m_spItemGroup);
  pItem->SetActiveIcon(m_spItemActive);
}

void VDefaultMenuDialog::BuildLabelText(VString& sLabelText)
{
  sLabelText = "";

  VDefaultMenuListControlItem* pItem = m_spCurrent;
  while (pItem != m_spRoot)
  {
    sLabelText.Format("%s/%s", pItem->GetText(), sLabelText.GetSafeStr());
    pItem = pItem->GetParentItem();
  }
  sLabelText.Format("/%s", sLabelText.GetSafeStr());
}

// VAppDefaultMenu

V_IMPLEMENT_DYNCREATE_ABSTRACT(VAppMenu, VAppModule, Vision::GetEngineModule())
V_IMPLEMENT_DYNCREATE(VDefaultMenu, VAppMenu, Vision::GetEngineModule());

VDefaultMenu::VDefaultMenu() : VAppMenu(), m_spDialog(NULL), m_iOpenMenuTriggerAlternative(-1)
{
  
}

void VDefaultMenu::Init()
{
  // Default cursor
  VGUIManager& manager = VGUIManager::GlobalManager();
  VCursor* pCursor = manager.LoadCursorResource("Textures/vapp_cursor.tga");
  manager.SetDefaultCursor(pCursor);

  m_spDialog = new VDefaultMenuDialog();

  // The dialog MUST be shown once so that everything is setup and other modules can
  // register their stuff during initialization
  VAppMenuContextPtr spContext = GetParent()->GetContext();
  spContext->ShowDialog(m_spDialog);
  spContext->CloseDialog(m_spDialog);
  m_spDialog->SetVisible(false);

  SetupIcon();

  Vision::Callbacks.OnUpdateSceneBegin += this;
}

void VDefaultMenu::DeInit()
{
  m_spOpenMenuIcon = NULL;
  m_spOpenMenuShortcutOverlay = NULL;
  m_spDialog = NULL;

  Vision::Callbacks.OnUpdateSceneBegin -= this;
}

void VDefaultMenu::OnHandleCallback(IVisCallbackDataObject_cl* pData)
{
  if (!m_bEnabled)
    return;

  if (pData->m_pSender == &Vision::Callbacks.OnUpdateSceneBegin)
  {
    // Only display icons if dialog is not visible. Use same visible mask as gui context.
    unsigned int guiContextVisibleBitmask = GetParent()->GetContext()->GetVisibleBitmask();
    m_spOpenMenuIcon->SetVisibleBitmask(IsVisible() ? VIS_ENTITY_INVISIBLE : guiContextVisibleBitmask);
    if (m_spOpenMenuShortcutOverlay != NULL)
      m_spOpenMenuShortcutOverlay->SetVisibleBitmask(IsVisible() ? VIS_ENTITY_INVISIBLE : guiContextVisibleBitmask);

    VInputMap* pInputMap = GetParent()->GetInputMap();
    if (pInputMap->GetTrigger(VAPP_MENU) || (IsVisible() && pInputMap->GetTrigger(VAPP_EXIT)))
      ToggleMainMenu();

    if (!IsVisible())
    {
      MapOpenMenuTouchArea();
      return;
    }

    if (pInputMap->GetTrigger(VAPP_MENU_UP))
      m_spDialog->SelectPreviousItem();
    else if (pInputMap->GetTrigger(VAPP_MENU_DOWN))
      m_spDialog->SelectNextItem();
    else if (pInputMap->GetTrigger(VAPP_MENU_CONFIRM))
      m_spDialog->TriggerSelectedItem();
    else if (pInputMap->GetTrigger(VAPP_MENU_BACK))
      m_spDialog->DoFadeOut(VDefaultMenuDialog::STATE_BACK);

    m_spDialog->BringToFront();
    m_spDialog->Update(Vision::GetTimer()->GetTimeDifference());
  }
}

VisCallback_cl* VDefaultMenu::RegisterItem(const VAppMenuItem& item, const char* szParentName /* = NULL */)
{
  VASSERT(m_spDialog != NULL);
  VDefaultMenuListControlItem* pParent = NULL;
  if (szParentName != NULL)
    pParent = m_spDialog->FindItem(szParentName);

  VisCallback_cl* pCallback = m_spDialog->AddItem(item, pParent);
  m_spDialog->RequestRefresh();
  return pCallback;
}

VArray<VisCallback_cl*> VDefaultMenu::RegisterGroup(const char* szGroupName, const VArray<VAppMenuItem>& items, const char* szParentName /* = NULL */, unsigned int uiSortingKey /* = 0 */, bool bMultiSelect /* = true */)
{
  VArray<VisCallback_cl*> callbacks;
  if (items.GetSize() == 0)
    return callbacks;

  VASSERT(m_spDialog != NULL);
  VDefaultMenuListControlItem* pParent = NULL;
  if (szParentName != NULL)
    pParent = m_spDialog->FindItem(szParentName);

  VDefaultMenuListControlItem* pGroup = m_spDialog->AddGroup(szGroupName, pParent, uiSortingKey, bMultiSelect);
  for (int i=0; i<items.GetSize(); ++i)
    callbacks.Add(m_spDialog->AddItem(items[i], pGroup));

  m_spDialog->RequestRefresh();
  return callbacks;
}

void VDefaultMenu::RemoveItem(const char* szItemName)
{
  VDefaultMenuListControlItem* pItem = m_spDialog->FindItem(szItemName);
  if (pItem && !pItem->HasChildren())
  {
    pItem->GetParentItem()->GetChildren().SafeRemove(pItem);
  }

  m_spDialog->RequestRefresh();
}

void VDefaultMenu::RemoveGroup(const char* szGroupName)
{
  VDefaultMenuListControlItem* pItem = m_spDialog->FindItem(szGroupName);
  if (pItem && pItem->HasChildren())
  {
    // Switch to parent of the group that should be removed, if current displayed group
    // is a child of the group which should be removed
    if (m_spDialog->IsChildOf(m_spDialog->GetSelectedItem(), pItem))
      m_spDialog->SwitchToGroup(pItem->GetParentItem());

    pItem->GetParentItem()->GetChildren().SafeRemove(pItem);
  }

  m_spDialog->RequestRefresh();
}

void VDefaultMenu::SetItemCheckState(const char* szItemName, bool bActive)
{
  VDefaultMenuListControlItem* pItem = m_spDialog->FindItem(szItemName);
  if (pItem && !pItem->HasChildren())
  {
    pItem->SetActive(bActive);
  }
}

bool VDefaultMenu::GetItemCheckState(const char* szItemName) const
{
  VDefaultMenuListControlItem* pItem = m_spDialog->FindItem(szItemName);
  if (pItem && !pItem->HasChildren())
  {
    return pItem->IsActive();
  }

  return false;
}

void VDefaultMenu::ToggleMainMenu()
{  
  VExitHandler* pExit = GetParent()->GetAppModule<VExitHandler>();
  if ((pExit != NULL) && pExit->IsExitDialogVisible())
    return;

  VASSERT(m_spDialog != NULL);
  if (m_spDialog->GetState() != VDefaultMenuDialog::STATE_NONE)
    return;

  if (!IsVisible())
  {
    VInputMap::LockInputMaps(true);
    GetParent()->GetInputMap()->SetEnabled(true);

    m_spDialog->SetVisible(true);

    VAppMenuContextPtr spContext = GetParent()->GetContext();
    spContext->ShowDialog(m_spDialog);
    m_spDialog->DoFadeIn();

    UnmapOpenMenuTouchArea();
  }
  else
  {
    m_spDialog->DoFadeOut(VDefaultMenuDialog::STATE_HIDE);
    VInputMap::LockInputMaps(false);

    MapOpenMenuTouchArea();
  }
}

void VDefaultMenu::Reset()
{
  m_spDialog->Reset();
  MapOpenMenuTouchArea();
}

void VDefaultMenu::SetupIcon()
{
  hkvVec2 pos(10.0f);
  hkvVec2 size;

  m_spOpenMenuIcon = new VisScreenMask_cl("Textures/vapp_gear.tga", VTM_FLAG_DEFAULT_NON_MIPMAPPED);
  m_spOpenMenuIcon->SetDepthWrite(FALSE);
  m_spOpenMenuIcon->SetTransparency (VIS_TRANSP_ALPHA);
  m_spOpenMenuIcon->SetFiltering(FALSE);
  m_spOpenMenuIcon->SetPos(pos.x, pos.y);
  m_spOpenMenuIcon->GetTargetSize(size.x, size.y);
  m_spOpenMenuIcon->SetVisibleBitmask(GetParent()->GetContext()->GetVisibleBitmask());

#if defined(WIN32)
  pos.x += size.x * 0.5f;

  m_spOpenMenuShortcutOverlay = new VisScreenMask_cl("Textures/vapp_shortcut_pc.tga", VTM_FLAG_DEFAULT_NON_MIPMAPPED);
  m_spOpenMenuShortcutOverlay->SetDepthWrite(FALSE);
  m_spOpenMenuShortcutOverlay->SetTransparency (VIS_TRANSP_ALPHA);
  m_spOpenMenuShortcutOverlay->SetFiltering(FALSE);
  m_spOpenMenuShortcutOverlay->SetOrder(-1);
  m_spOpenMenuShortcutOverlay->SetPos(pos.x, pos.y);
  m_spOpenMenuShortcutOverlay->SetVisibleBitmask(GetParent()->GetContext()->GetVisibleBitmask());
#endif

  MapOpenMenuTouchArea();
}

void VDefaultMenu::MapOpenMenuTouchArea()
{
  if (m_iOpenMenuTriggerAlternative >= 0)
    return;

  hkvVec2 pos;
  m_spOpenMenuIcon->GetPos(pos.x, pos.y);

  hkvVec2 size;
  m_spOpenMenuIcon->GetTargetSize(size.x, size.y);

#if defined(SUPPORTS_MULTITOUCH)
  VTouchArea* menuArea = new VTouchArea(VInputManager::GetTouchScreen(), VRectanglef(hkvVec2::ZeroVector(), pos + size), 2000.0f);
  m_iOpenMenuTriggerAlternative = GetParent()->GetInputMap()->MapTrigger(VAPP_MENU, menuArea, CT_TOUCH_ANY, VInputOptions::Once(ONCE_ON_RELEASE));
#endif
}

void VDefaultMenu::UnmapOpenMenuTouchArea()
{
  if (m_iOpenMenuTriggerAlternative < 0)
    return;

  GetParent()->GetInputMap()->UnmapInput(VAPP_MENU, m_iOpenMenuTriggerAlternative);
  m_iOpenMenuTriggerAlternative = -1;
}

/*
 * Havok SDK - Base file, BUILD(#20131218)
 * 
 * Confidential Information of Havok.  (C) Copyright 1999-2013
 * Telekinesys Research Limited t/a Havok. All Rights Reserved. The Havok
 * Logo, and the Havok buzzsaw logo are trademarks of Havok.  Title, ownership
 * rights, and intellectual property rights in the Havok software remain in
 * Havok and/or its suppliers.
 * 
 * Use of this software for evaluation purposes is subject to and indicates
 * acceptance of the End User licence Agreement for this product. A copy of
 * the license is included with this software and is also available from salesteam@havok.com.
 * 
 */
