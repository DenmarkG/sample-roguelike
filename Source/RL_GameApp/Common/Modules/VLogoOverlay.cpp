/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#include <Vision/Runtime/Framework/VisionApp/Modules/VLogoOverlay.hpp>
#include <Vision/Runtime/Framework/VisionApp/VAppImpl.hpp>

V_IMPLEMENT_DYNCREATE(VLogoOverlay, VAppModule, Vision::GetEngineModule());

// The windows anarchy build already has a watermark, so no logo needed.
#if !(defined(HK_ANARCHY) && defined(WIN32))
  #define SHOW_LOGO
#endif

void VLogoOverlay::Init()
{
#if defined(SHOW_LOGO)
  Vision::Callbacks.OnVideoChanged += this;

#if defined( HK_ANARCHY )
  m_spLogoOverlay = new VisScreenMask_cl("Textures/Anarchy_Logo_128x128.dds");
#else
  m_spLogoOverlay = new VisScreenMask_cl("Textures/Havok_Logo_128x64.dds");
#endif
  m_spLogoOverlay->SetDepthWrite(FALSE);
  m_spLogoOverlay->SetTransparency (VIS_TRANSP_ALPHA);
  m_spLogoOverlay->SetFiltering(FALSE);

  RefreshLayout();

  m_spLogoOverlay->SetColor(VColorRef(255, 255, 255, 255));
  m_spLogoOverlay->GetTextureObject()->SetResourceFlag(VRESOURCEFLAG_AUTODELETE); 
#endif
}

void VLogoOverlay::DeInit()
{
#if defined(SHOW_LOGO)
  m_spLogoOverlay = NULL;
  Vision::Callbacks.OnVideoChanged -= this;
#endif
}

void VLogoOverlay::OnHandleCallback(IVisCallbackDataObject_cl* pData)
{
  if (pData->m_pSender == &Vision::Callbacks.OnVideoChanged)
    RefreshLayout();
}

void VLogoOverlay::RefreshLayout()
{
  if (m_spLogoOverlay == NULL)
    return;

  float fWidth = 0.0f, fHeight = 0.0f;
  m_spLogoOverlay->GetTargetSize(fWidth, fHeight);

  const VRectanglef screenExtents = GetScreenExtents();
  const float fVerticalBorder = 2.0f;
  const float fHorizontalBorder = 18.0f;

  hkvVec2 vPos;

  // X-Coordinate
  if (m_eAlignment == ALIGN_TOPLEFT || m_eAlignment == ALIGN_BOTTOMLEFT)
  {
    vPos.x = screenExtents.m_vMin.x + fHorizontalBorder;
  }
  else if (m_eAlignment == ALIGN_TOPRIGHT || m_eAlignment == ALIGN_BOTTOMRIGHT)
  {
    vPos.x = screenExtents.m_vMax.x - fWidth - fHorizontalBorder;
  }
  else
  {
    vPos.x = screenExtents.m_vMin.x + (screenExtents.GetSizeX() - fWidth) * 0.5f;
  }

  // Y-Coordinate
  if (m_eAlignment == ALIGN_TOPLEFT || m_eAlignment == ALIGN_TOPRIGHT || m_eAlignment == ALIGN_TOP)
  {
    vPos.y = screenExtents.m_vMin.y + fVerticalBorder;
  }
  else
  {
    vPos.y = screenExtents.m_vMax.y - fHeight - fVerticalBorder;
  }
  
  m_spLogoOverlay->SetPos(vPos.x, vPos.y);
}

const VRectanglef VLogoOverlay::GetScreenExtents() const
{
  return VRectanglef(0.0f, 0.0f, static_cast<float>(Vision::Video.GetXRes()), static_cast<float>(Vision::Video.GetYRes()));
}

void VLogoOverlay::SetAlignment(Alignment eAlignment)
{
  m_eAlignment = eAlignment;
  RefreshLayout();
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
