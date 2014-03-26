/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#include <Vision/Runtime/Framework/VisionApp/VAppModule.hpp>

VColorRef VAppMenuColors::m_colors[] =
{
  VColorRef( 68,  68,  68, 255), // COLOR_DIALOG_BG
  VColorRef(200, 200, 200, 255), // COLOR_TEXT
  VColorRef( 32,  32,  32, 255), // COLOR_LIST_CONTROL_BG
  VColorRef( 52,  52,  52, 255), // COLOR_LIST_ITEM_BG
  VColorRef( 42,  42,  42, 255), // COLOR_LIST_GROUP_BG
  VColorRef(200, 200, 200, 255), // COLOR_LIST_ITEM_TEXT_NORMAL
  VColorRef(255, 255, 255, 255), // COLOR_LIST_ITEM_TEXT_OVER
  VColorRef(253, 178,   0, 255)  // COLOR_LIST_ITEM_TEXT_SELECTED
};

//////////////////////////////////////////////////////////////////////////

int VAppMenuContext::ShowDialogModal(VDialog *pParent, const char *szDialogResource, const hkvVec2 &vPos, IVisApp_cl *pRunApp)
{
  VASSERT_ALWAYS_MSG(false, "Not supported! Use ShowDialog(...) and pDialog->SetDialogFlags(DIALOGFLAGS_MODAL).");
  return 0;
}

int VAppMenuContext::ShowDialogModal(VDialog *pDialog, IVisApp_cl *pRunApp)
{
  VASSERT_ALWAYS_MSG(false, "Not supported! Use ShowDialog(...) and pDialog->SetDialogFlags(DIALOGFLAGS_MODAL).");
  return 0;
}

VDialog* VAppMenuContext::ShowDialog(const char *szDialogResource)
{
  SetActivate(true);
  return VGUIMainContext::ShowDialog(szDialogResource);
}

void VAppMenuContext::ShowDialog(VDialog* pDialog)
{
  SetActivate(true);
  VGUIMainContext::ShowDialog(pDialog);
}

void VAppMenuContext::CloseDialog(VDialog* pDialog)
{
  VGUIMainContext::CloseDialog(pDialog);
  if (m_openDialogs.Count() == 0)
    SetActivate(false);
}

void VAppMenuContext::OnRender()
{
  bool bWireframe = Vision::Renderer.GetWireframeMode();
  Vision::Renderer.SetWireframeMode(false);
  {
    VGUIMainContext::OnRender();
  }
  Vision::Renderer.SetWireframeMode(bWireframe);
}

void VAppMenuContext::SetActivate(bool bStatus)
{
  VGUIMainContext::SetActivate(bStatus);
}

//////////////////////////////////////////////////////////////////////////

V_IMPLEMENT_DYNCREATE(VAppModule, VTypedObject, Vision::GetEngineModule());

int VAppModule::GetCallbackIndex(IVisCallbackDataObject_cl* pData)
{
  return GetCallbackIndex(m_callbacks, pData);
}

int VAppModule::GetCallbackIndex(VArray<VisCallback_cl*>& callbacks, IVisCallbackDataObject_cl* pData)
{
  for (int i=0; i<callbacks.GetSize(); ++i)
  {
    if (pData->m_pSender == callbacks[i])
    {
      VAppMenuDataObject* pCallbackData = (VAppMenuDataObject*)pData;

      // !!!
      // Notification about upcoming deletion of the SENDER, thus we de-register from the callback
      if (pCallbackData->m_uiType == VAppMenuDataObject::TYPE_DELETE)
      {
        *callbacks[i] -= this;
        callbacks[i] = NULL;
        return -1;
      }
      else
      {
        return pCallbackData->m_iAction;
      }
    }
  }

  return -1;
}

void VAppModule::RegisterCallbacks()
{
  RegisterCallbacks(m_callbacks);
}

void VAppModule::RegisterCallbacks(VArray<VisCallback_cl*>& callbacks)
{
  // Simply register at all given callbacks
  for (int i=0; i<callbacks.GetSize(); ++i)
  {
    if (callbacks[i])
      *callbacks[i] += this;
  }
}

void VAppModule::DeRegisterCallbacks()
{
  return DeRegisterCallbacks(m_callbacks);
}

void VAppModule::DeRegisterCallbacks(VArray<VisCallback_cl*>& callbacks)
{
  // De-register at all given callbacks
  for (int i=0; i<callbacks.GetSize(); ++i)
  {
    if (callbacks[i])
      *callbacks[i] -= this;
  }
}

//////////////////////////////////////////////////////////////////////////

VStyledButton::VStyledButton(const char* szText, bool bUseGradient, VisFontPtr spFont, float fScale, float fBorderWidth, float fFontScale)
  : m_fBorderWidth(fBorderWidth)
{
  SetText(szText);
  m_TextCfg.SetFont(spFont);
  m_TextCfg.m_States[VWindowBase::NORMAL].SetColor(VAppMenuColors::GetColor(VAppMenuColors::COLOR_LIST_ITEM_TEXT_NORMAL));
  m_TextCfg.m_States[VWindowBase::MOUSEOVER].SetColor(VAppMenuColors::GetColor(VAppMenuColors::COLOR_LIST_ITEM_TEXT_OVER));
  m_TextCfg.m_States[VWindowBase::SELECTED].SetColor(VAppMenuColors::GetColor(VAppMenuColors::COLOR_LIST_ITEM_TEXT_SELECTED));
  m_TextCfg.SetHorizontalAlignment(VisFont_cl::ALIGN_CENTER);
  m_TextCfg.SetVerticalAlignment(VisFont_cl::ALIGN_CENTER);
  m_TextCfg.SetScaling(fFontScale);
  m_TextCfg.FinishSetup();

  if (bUseGradient)
  {
    VTextureObject* pGrad = Vision::TextureManager.Load2DTexture("Textures/vapp_grad.dds", VTM_FLAG_DEFAULT_NON_MIPMAPPED|VTM_FLAG_NO_DOWNSCALE);
    m_ButtonCfg.m_States[VWindowBase::NORMAL].SetTexture(pGrad);
    m_ButtonCfg.m_States[VWindowBase::NORMAL].SetColor(VColorRef(0, 0, 0, 35));
  }
}

void VStyledButton::OnPaint(VGraphicsInfo& Graphics, const VItemRenderInfo& parentState)
{
  const VRectanglef rect = GetBoundingBox();
  const float fBorderWidth = m_fBorderWidth;
  VColorRef color = IsMouseOver() ? VAppMenuColors::GetColor(VAppMenuColors::COLOR_LIST_ITEM_BG) : VAppMenuColors::GetColor(VAppMenuColors::COLOR_LIST_GROUP_BG);
  const VSimpleRenderState_t iProperties = VGUIManager::DefaultGUIRenderState();

  Graphics.Renderer.DrawSolidQuad(rect.m_vMin, rect.m_vMax, color, iProperties);

  color = VAppMenuColors::GetColor(VAppMenuColors::COLOR_LIST_CONTROL_BG);
  Graphics.Renderer.DrawSolidQuad(rect.m_vMin, hkvVec2(rect.m_vMax.x, rect.m_vMin.y + fBorderWidth), color, iProperties);
  Graphics.Renderer.DrawSolidQuad(hkvVec2(rect.m_vMin.x, rect.m_vMax.y - fBorderWidth), rect.m_vMax, color, iProperties);
  Graphics.Renderer.DrawSolidQuad(hkvVec2(rect.m_vMin.x, rect.m_vMin.y + fBorderWidth), hkvVec2(rect.m_vMin.x + fBorderWidth, rect.m_vMax.y - fBorderWidth), color, iProperties);
  Graphics.Renderer.DrawSolidQuad(hkvVec2(rect.m_vMax.x - fBorderWidth, rect.m_vMin.y + fBorderWidth), hkvVec2(rect.m_vMax.x, rect.m_vMax.y - fBorderWidth), color, iProperties);

  VPushButton::OnPaint(Graphics, parentState);
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
