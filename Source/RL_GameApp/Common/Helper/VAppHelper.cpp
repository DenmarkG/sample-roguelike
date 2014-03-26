/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#include <Vision/Runtime/Framework/VisionApp/Helper/VAppHelper.hpp>
#include <Vision/Runtime/EnginePlugins/VisionEnginePlugin/Rendering/RendererNode/VRendererNodeCommon.hpp>
#include <Vision/Runtime/Engine/Renderer/VisApiSimpleRendererNode.hpp>
#include <Vision/Runtime/EnginePlugins/VisionEnginePlugin/Rendering/Postprocessing/ToneMapping.hpp>

#ifdef SUPPORTS_SHADOW_MAPS
  #include <Vision/Runtime/EnginePlugins/VisionEnginePlugin/Rendering/ShadowMapping/IVShadowMapComponent.hpp>

  #if defined(_VISION_PSP2) || defined( _VISION_MOBILE ) || defined( HK_ANARCHY ) || defined( _VISION_APOLLO )    // TODO: Have Apollo define _VISION_MOBILE.
    #include <Vision/Runtime/EnginePlugins/VisionEnginePlugin/Rendering/ShadowMapping/VMobileShadowMapComponentSpotDirectional.hpp>
  #else
    #include <Vision/Runtime/EnginePlugins/VisionEnginePlugin/Rendering/ShadowMapping/VShadowMapComponentPoint.hpp>
    #include <Vision/Runtime/EnginePlugins/VisionEnginePlugin/Rendering/ShadowMapping/VShadowMapComponentSpotDirectional.hpp>
  #endif
#endif

#if defined( _VISION_MOBILE ) || defined( HK_ANARCHY ) || defined( _VISION_APOLLO )    // TODO: Have Apollo define _VISION_MOBILE.
  #include <Vision/Runtime/EnginePlugins/VisionEnginePlugin/Rendering/MobileForwardRenderer/VMobileForwardRenderer.hpp>
#elif defined( SUPPORTS_RENDERERNODES )
  #include <Vision/Runtime/EnginePlugins/VisionEnginePlugin/Rendering/ForwardRenderer/ForwardRenderer.hpp>
#endif

void VAppHelper::SetShadowsForLight(VisLightSource_cl *pLight, bool bStatus)
{
#if defined(SUPPORTS_SHADOW_MAPS)
  VASSERT(pLight);

  // Convenience function only handles renderer node 0!
  VRendererNodeCommon *pRendererNode = vdynamic_cast<VRendererNodeCommon*>(Vision::Renderer.GetRendererNode(0));
  if (pRendererNode == NULL)
  {
    hkvLog::Warning("Renderer node 0 not set. VAppHelper::SetShadowsForLight can not be used.");
    return;
  }

  IVShadowMapComponent *pComponent = IVShadowMapComponent::GetShadowMapComponent(pLight, pRendererNode);
  if (!bStatus)
  {
    if (pComponent != NULL)
      pLight->RemoveComponent(pComponent);
  }
  else if (pComponent == NULL)
  {
#if defined(_VISION_PSP2) || defined(_VISION_MOBILE) || defined(HK_ANARCHY) || defined(_VISION_APOLLO) // TODO: Have Apollo define _VISION_MOBILE.

    const unsigned int nShadowMapSize = 512;
    // Note: shadows for VIS_LIGHT_POINT not supported
    if ((pLight->GetType() == VIS_LIGHT_DIRECTED) || (pLight->GetType() == VIS_LIGHT_SPOTLIGHT))
    {
      pComponent = new VMobileShadowMapComponentSpotDirectional(0);
      pComponent->SetShadowMapSize(nShadowMapSize);
    }

    if (pComponent) 
    {
      pComponent->SetShadowMappingMode(SHADOW_MAPPING_MODE_PCF4);
      pLight->AddComponent(pComponent);
    }

#else

    unsigned int nShadowMapSize = 1024;
    if (pLight->GetType() == VIS_LIGHT_DIRECTED)
    {
      VShadowMapComponentSpotDirectional *pSpotDirComponent = new VShadowMapComponentSpotDirectional(0);
      pSpotDirComponent->SetCascadeCount(2);
      pSpotDirComponent->SetCascadeRange(0, 512);
      pSpotDirComponent->SetCascadeRange(1, 2048);
      pSpotDirComponent->SetShadowMapSize(nShadowMapSize);
      pComponent = pSpotDirComponent;
    }
    else if (pLight->GetType() == VIS_LIGHT_POINT)
    {
      pComponent = new VShadowMapComponentPoint(0);
      pComponent->SetShadowMapSize(nShadowMapSize);
    }
    else if (pLight->GetType() == VIS_LIGHT_SPOTLIGHT)
    {
      pComponent = new VShadowMapComponentSpotDirectional(0);
      pComponent->SetShadowMapSize(nShadowMapSize);
    }

    if (pComponent) 
    {
      pComponent->SetShadowMappingMode(SHADOW_MAPPING_MODE_PCF8);
      pLight->AddComponent(pComponent);
    }

#endif
  }
#endif //SUPPORTS_SHADOW_MAPS
}

void VAppHelper::CreateForwardRenderer()
{
#if defined(SUPPORTS_RENDERERNODES)

#if defined(_VISION_MOBILE) || defined(HK_ANARCHY) || defined(_VISION_APOLLO) // TODO: Have Apollo define _VISION_MOBILE.
  VRendererNodeCommon *pRenderer = new VMobileForwardRenderingSystem(Vision::Contexts.GetMainRenderContext());
#else
  VRendererNodeCommon *pRenderer = new VForwardRenderingSystem(Vision::Contexts.GetMainRenderContext());
#endif

  VASSERT(pRenderer);
  VPostProcessToneMapping *pToneMapper = new VPostProcessToneMapping(TONEMAP_NONE, 1.0f, 1.0f, 0.0f);
  VASSERT(pToneMapper);
  pRenderer->AddComponent(pToneMapper);

  pRenderer->InitializeRenderer();

  // Apply renderer node at last
  VSmartPtr<IVRendererNode> spOldRenderer = Vision::Renderer.GetRendererNode(0);
  Vision::Renderer.SetRendererNode(0, pRenderer);

  if (spOldRenderer != NULL)
  {
    spOldRenderer->DeInitializeRenderer();
  }

  // Disable depth fog
  VFogParameters fog = Vision::World.GetFogParameters();
  fog.depthMode = VFogParameters::Off;
  Vision::World.SetFogParameters(fog);
#endif
}

void VAppHelper::DestroyForwardRenderer()
{
#if defined(SUPPORTS_RENDERERNODES)
  VSimpleRendererNode* pRenderer = new VSimpleRendererNode(Vision::Contexts.GetMainRenderContext());
  pRenderer->InitializeRenderer();
  Vision::Renderer.SetRendererNode(0, pRenderer);
#endif
}

float VAppHelper::GetUIScalingFactor()
{
  const float fReferenceResolution = 1280.0f;
  const float fReferenceDisplaySize = 4.6f;
  const float fKernscheFakeKonstante = 1.73f;
  const float fBagarscherFakeExponent = 0.2f;

  float fScale = 1.0f;
  const hkvVec2 vRes = hkvVec2((float)Vision::Video.GetXRes(), (float)Vision::Video.GetYRes());

#if defined(_VISION_MOBILE) || defined (_VISION_PSP2)  
  const float fDisplaySizeInInch = vRes.getLength() / Vision::Video.GetDeviceDpi();  

  fScale = (vRes.x / fReferenceResolution) * fKernscheFakeKonstante * hkvMath::pow(fReferenceDisplaySize / fDisplaySizeInInch, fBagarscherFakeExponent);

#elif !defined(WIN32)
  fScale = vRes.x / fReferenceResolution;

#endif

  return hkvMath::Max(fScale, 0.5f);
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
