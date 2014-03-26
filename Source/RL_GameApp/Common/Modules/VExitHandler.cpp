/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#include <Vision/Runtime/Framework/VisionApp/Modules/VExitHandler.hpp>
#include <Vision/Runtime/Framework/VisionApp/VAppImpl.hpp>
#include <Vision/Runtime/Framework/VisionApp/VAppModule.hpp>


V_IMPLEMENT_SERIAL(VExitDialog, VDialog, 0, &VGUIManager::GUIModule());

VExitDialog::VExitDialog() : VDialog(), m_bExitTriggered(false), m_bUnlockInput(false)
{
  const float fScale = VAppHelper::GetUIScalingFactor();

  const hkvVec2 vSize= hkvVec2(400.0f, 75.0f) * fScale;     ///< Size of the exit dialog
  const float fTextAreaHeight = 0.42f;                      ///< Height of the label text area in percent (height in pixel = vSize.y*fTextAreaHeight)
  const float fInnerBorder = hkvMath::ceil(1.5f * fScale);  ///< Width of the button's border
  const float fOuterBorder = 3.0f * fScale;                 ///< Width of the border between the dialogs edges and the buttons
  const float fFontScale = 0.76f * fScale;

  m_iBackColor = VAppMenuColors::GetColor(VAppMenuColors::COLOR_DIALOG_BG);
  SetSize(vSize.x, vSize.y);
  SetPosition((static_cast<float>(Vision::Video.GetXRes()) - vSize.x)*0.5f, (static_cast<float>(Vision::Video.GetYRes()) - vSize.y)*0.5f);

  VisFontPtr spFont = Vision::Fonts.LoadFont("Fonts/OpenSans_22.fnt");
  VASSERT(spFont != NULL);

  m_pLabel = new VTextLabel();
  m_pLabel->SetText("Are you sure you want to exit?");
  m_pLabel->Text().SetFont(spFont);
  m_pLabel->Text().m_States[VWindowBase::NORMAL].SetColor(VAppMenuColors::GetColor(VAppMenuColors::COLOR_LIST_ITEM_TEXT_NORMAL));
  m_pLabel->Text().m_States[VWindowBase::MOUSEOVER].SetColor(VAppMenuColors::GetColor(VAppMenuColors::COLOR_LIST_ITEM_TEXT_NORMAL));
  m_pLabel->Text().m_States[VWindowBase::SELECTED].SetColor(VAppMenuColors::GetColor(VAppMenuColors::COLOR_LIST_ITEM_TEXT_NORMAL));
  m_pLabel->Text().SetScaling(fFontScale);
  m_pLabel->Text().SetHorizontalAlignment(VisFont_cl::ALIGN_CENTER);
  m_pLabel->Text().SetVerticalAlignment(VisFont_cl::ALIGN_CENTER);
  m_pLabel->SetSize(vSize.x, vSize.y*fTextAreaHeight);
  m_pLabel->SetPosition(0.0f, 0.0f);
  m_pLabel->Text().FinishSetup();
  AddControl(m_pLabel);

  const float fInvTextAreaHeight = 1.0f - fTextAreaHeight;

  m_pCancelButton = new VStyledButton("Cancel", true, spFont, fScale, fInnerBorder, fFontScale);
  m_pCancelButton->SetSize(vSize.x*0.5f - fOuterBorder*1.5f, vSize.y*fInvTextAreaHeight - fOuterBorder*2.0f);
  m_pCancelButton->SetPosition(fOuterBorder, vSize.y*fTextAreaHeight + fOuterBorder);
  AddControl(m_pCancelButton);

  m_pExitButton = new VStyledButton("Exit", true, spFont, fScale, fInnerBorder, fFontScale);
  m_pExitButton->SetSize(vSize.x*0.5f - fOuterBorder*1.5f, vSize.y*fInvTextAreaHeight - fOuterBorder*2.0f);
  m_pExitButton->SetPosition(vSize.x*0.5f + fOuterBorder*0.5f, vSize.y*fTextAreaHeight + fOuterBorder);
  AddControl(m_pExitButton);

  m_bExitTriggered = false;

  SetDialogFlags(DIALOGFLAGS_MODAL);
}

void VExitDialog::OnItemClicked(VMenuEventDataObject *pEvent)
{
  VDialog::OnItemClicked(pEvent);

  if (pEvent->m_pItem == m_pExitButton)
    m_bExitTriggered = true;
  else if (pEvent->m_pItem == m_pCancelButton)
    CloseDialog();
}

void VExitDialog::CloseDialog()
{
  GetContext()->CloseDialog(this);
  SetVisible(false);
  
  m_bExitTriggered = false;

  if (m_bUnlockInput)
    VInputMap::LockInputMaps(false);
}

// VExitHandler

V_IMPLEMENT_DYNCREATE(VExitHandler, VAppModule, Vision::GetEngineModule());

VExitHandler::VExitHandler() : VAppModule(), m_spExitDlg(NULL), m_bShowExitDialog(true)
{
#if defined(WIN32)
  m_bShowExitDialog = false;
#endif
}

void VExitHandler::Init()
{
  Vision::Callbacks.OnFrameUpdatePreRender += this;
  Vision::Callbacks.OnVideoChanged += this;
  
  m_spExitDlg = new VExitDialog();
  VASSERT(m_spExitDlg);
  m_spExitDlg->SetVisible(false);
}

void VExitHandler::DeInit()
{
  m_spExitDlg = NULL;

  Vision::Callbacks.OnFrameUpdatePreRender -= this;
  Vision::Callbacks.OnVideoChanged -= this;
}

void VExitHandler::OnHandleCallback(IVisCallbackDataObject_cl* pData)
{
  if (pData->m_pSender == &Vision::Callbacks.OnFrameUpdatePreRender)
  {
    if (!m_bEnabled)
      return;

    VInputMap* pInputMap = GetParent()->GetInputMap();
    if (pInputMap->GetTrigger(VAPP_EXIT))
    {
      VAppMenu* pMenu = GetParent()->GetAppModule<VAppMenu>();
      if (pMenu && pMenu->IsVisible())
        return;

      if (!m_bShowExitDialog)
      {
        VAppBase::Get()->Quit();
      }
      else if (!m_spExitDlg->IsVisible())
      {
        VAppMenu* pMenu = GetParent()->GetAppModule<VAppMenu>();
        if (pMenu != NULL && pMenu->IsVisible())
          pMenu->ToggleMainMenu();

        if (!VInputMap::AreInputMapsLocked())
        {
          VInputMap::LockInputMaps(true);
          m_spExitDlg->SetUnlockInput(true);
        }
        else
        {
          m_spExitDlg->SetUnlockInput(false);
        }
        GetParent()->GetInputMap()->SetEnabled(true);

        m_spExitDlg->SetVisible(true);

        VAppMenuContextPtr spContext = GetParent()->GetContext();
        spContext->ShowDialog(m_spExitDlg);
      }
    }
    else if (m_spExitDlg->IsVisible())
    {
      VExitDialog* pDialog = static_cast<VExitDialog*>(m_spExitDlg.GetPtr());
      if (pDialog->IsExitTriggered())
      {
        VAppBase::Get()->Quit();
        return;
      }

      if (pInputMap->GetTrigger(VAPP_MENU_CONFIRM))
        VAppBase::Get()->Quit();
      else if (pInputMap->GetTrigger(VAPP_MENU_BACK))
        pDialog->CloseDialog();
    }
  }
  else if (pData->m_pSender == &Vision::Callbacks.OnVideoChanged)
  {
    const hkvVec2& vSize = m_spExitDlg->GetSize();
    m_spExitDlg->SetPosition((static_cast<float>(Vision::Video.GetXRes()) - vSize.x)*0.5f, (static_cast<float>(Vision::Video.GetYRes()) - vSize.y)*0.5f);
  }
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
