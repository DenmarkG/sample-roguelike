/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#include <Vision/Runtime/Framework/VisionApp/Modules/VDebugProfiling.hpp>
#include <Vision/Runtime/Framework/VisionApp/VAppImpl.hpp>

V_IMPLEMENT_DYNCREATE(VDebugProfiling, VAppModule, Vision::GetEngineModule());

void VDebugProfiling::Init()
{
  VAppMenu* pMainMenu = GetParent()->GetAppModule<VAppMenu>();
  if (pMainMenu == NULL)
    return;

  VProfilingNode* pRoot = Vision::Profiling.GetProfilingRootNode();
  if (pRoot)
  {
    VAppMenuItems items;
    const unsigned int iCount = Vision::Profiling.GetNumOfGroups();
    for (unsigned int i=0; i<iCount; ++i)
    {
      VProfilingNode* pNode = pRoot->Children().GetAt(i);
      if (pNode)
        items.Add(VAppMenuItem(pNode->GetName(), i, 0, true));
    }

    m_callbacks = pMainMenu->RegisterGroup("Debug Profiling", items, NULL, VAPP_DEFAULT_SORTING_1, false);
    RegisterCallbacks();
  }
}

void VDebugProfiling::DeInit()
{
  DeRegisterCallbacks();
}

void VDebugProfiling::OnHandleCallback(IVisCallbackDataObject_cl* pData)
{
  int iIndex = GetCallbackIndex(pData);
  if (iIndex >= 0)
  {
    if (Vision::Profiling.IsPageVisible(iIndex))
      Vision::Profiling.Hide();
    else
      Vision::Profiling.SetPage(iIndex);
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
