/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#include <Vision/Runtime/Framework/VisionApp/Modules/VHelp.hpp>
#include <Vision/Runtime/Framework/VisionApp/VAppImpl.hpp>

V_IMPLEMENT_DYNCREATE(VHelp, VAppModule, Vision::GetEngineModule());

void VHelp::Init()
{
  Vision::Callbacks.OnUpdateSceneFinished += this;

  VAppMenu* pMainMenu = GetParent()->GetAppModule<VAppMenu>();
  if (pMainMenu == NULL)
  {
    SetEnabled(false);
    m_bToggleEnabled = true;
    return;
  }

  m_callbacks.Append(pMainMenu->RegisterItem(VAppMenuItem("Help", 0, VAPP_DEFAULT_SORTING_3, true)));
  RegisterCallbacks();

  SetEnabled(false);
}

void VHelp::DeInit()
{
  DeRegisterCallbacks();
  Vision::Callbacks.OnUpdateSceneFinished -= this;
}

void VHelp::OnHandleCallback(IVisCallbackDataObject_cl* pData)
{
  if (pData->m_pSender == &Vision::Callbacks.OnUpdateSceneFinished)
  {
    if (m_bToggleEnabled && GetParent()->GetInputMap()->GetTrigger(VAPP_MENU))
      SetEnabled(!IsEnabled());

    if (IsEnabled())
    {
      const int iLineHeight = 16;
      const int iOffset = Vision::Video.GetYRes() - (m_text.GetSize() + 3) * iLineHeight;
      for (int i=0; i<m_text.GetSize(); ++i)
      {
        if (m_text[i])
          Vision::Message.Print(1, 10, iOffset + i*iLineHeight, m_text[i]);
      }
    }
  }

  int iIndex = GetCallbackIndex(pData);
  if (iIndex >= 0)
    SetEnabled(!IsEnabled());
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
