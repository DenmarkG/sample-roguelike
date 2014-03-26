/*
 *
 * Confidential Information of Telekinesys Research Limited (t/a Havok). Not for disclosure or distribution without Havok's
 * prior written consent. This software contains code, techniques and know-how which is confidential and proprietary to Havok.
 * Product and Trade Secret source code contains trade secrets of Havok. Havok Software (C) Copyright 1999-2013 Telekinesys Research Limited t/a Havok. All Rights Reserved. Use of this software is subject to the terms of an end user license agreement.
 *
 */

#ifndef __V_DEFAULT_MENU
#define __V_DEFAULT_MENU

#include <Vision/Runtime/Engine/System/Vision.hpp>
#include <Vision/Runtime/Framework/VisionApp/VAppModule.hpp>
#include <Vision/Runtime/EnginePlugins/VisionEnginePlugin/GUI/VMenuIncludes.hpp>

/// \brief
///   Helper class representing one entry within the default menu.
///
/// This class is responsible for correctly rendering one entry within the default menu, but
/// also to represent the data structure of the menu itself. Basically each VDefaultMenuListControlItem
/// does have multiple childs and belongs to exactly one parent, consequently forming the menu TREE structure.
class VDefaultMenuListControlItem : public VListControlItem
{
public:
  VDefaultMenuListControlItem();
  VDefaultMenuListControlItem(const char* szText, unsigned int uiSortingKey, bool bCheckable, bool bIsChecked);
  virtual ~VDefaultMenuListControlItem();

  virtual void OnPaint(VGraphicsInfo &Graphics, const VItemRenderInfo &parentState) HKV_OVERRIDE;

  /// \brief
  ///   Adds the given item as a child.
  void AddChild(VDefaultMenuListControlItem* pChild);

  /// \brief
  ///   Creates the callback which is triggered when the item is activated/clicked.
  VisCallback_cl* CreateCallback(int iAction);

  void TriggerCallback();

  inline bool HasChildren() const { return m_children.Count() > 0; }
  inline VRefCountedCollection<VDefaultMenuListControlItem>& GetChildren() { return m_children; }
  inline VDefaultMenuListControlItem* GetParentItem() { return m_pParent; }
  inline const VDefaultMenuListControlItem* GetParentItem() const { return m_pParent; }

  inline void SetGroupIcon(VTextureObject* pTexture) { m_spGroupIcon = pTexture; }
  inline void SetActiveIcon(VTextureObject* pTexture) { m_spActiveIcon = pTexture; }

  /// \brief
  ///   Returns the key used to sort the items on one level.
  inline int GetSortingKey() const { return m_uiSortingKey; }

  inline void SetParent(VDefaultMenuListControlItem* pParent) { m_pParent = pParent; }

  /// \brief
  ///   Sets the active state of the item.
  inline void SetActive(bool bActive) { m_bActive = bActive; }

  /// \brief
  ///   Returns whether the item is active or not.
  inline bool IsActive() const { return m_bActive || !m_bCheckable; }

private:
  static float m_fSpacing;

  bool m_bCheckable;
  bool m_bActive;
  unsigned int m_uiSortingKey;

  VDefaultMenuListControlItem* m_pParent;
  VRefCountedCollection<VDefaultMenuListControlItem> m_children;

  VTextureObjectPtr m_spGroupIcon;
  VTextureObjectPtr m_spActiveIcon;

  VisCallback_cl* m_pCallback;
  VAppMenuDataObject* m_pCallbackData;
};

/// \brief
///   Dialog representing the default menu.
class VDefaultMenuDialog : public VDialog
{
public:
  enum VDialogState
  {
    STATE_NONE = 0,
    STATE_FADE_IN,
    STATE_FADE_OUT,
    STATE_HIDE,
    STATE_OPEN,
    STATE_BACK
  };

  VDefaultMenuDialog();
  virtual ~VDefaultMenuDialog();

  void Update(float fDeltaTime);

  const VDialogState& GetState() const { return m_state; }

  /// \brief
  ///   Helper function to add a group to the dialog.
  ///
  /// \param szGroupName
  ///   Name of the group to be added.
  ///
  /// \param pParent
  ///   Parent item.
  ///
  /// \param uiSortingKey
  ///   Sorting key used to sort the items within the list control.
  ///
  /// \param bMultiSelect
  ///   Flag indicating whether the group allows multi selection of it's children or not.
  ///
  /// \sa VAppMenu::RegisterGroup
  VDefaultMenuListControlItem* AddGroup(const char* szGroupName, VDefaultMenuListControlItem* pParent, unsigned int uiSortingKey, bool bMultiSelect);

  /// \brief
  ///   Helper function to add an item to the dialog.
  ///
  /// \param item
  ///   Application menu item to be added.
  ///
  /// \param pParent
  ///   Parent item.
  ///
  /// \sa VAppMenu::RegisterItem
  VisCallback_cl* AddItem(const VAppMenuItem& item, VDefaultMenuListControlItem* pParent);

  /// \brief
  ///   Returns the item with the given name (NULL if not found).
  VDefaultMenuListControlItem* FindItem(const char* szItemName);

  virtual void OnItemClicked(VMenuEventDataObject *pEvent) HKV_OVERRIDE;

  void SelectPreviousItem();
  void SelectNextItem();
  void TriggerSelectedItem();
  void BackToParentGroup();
  
  void SwitchToRoot();
  void SwitchToGroup(VDefaultMenuListControlItem* pItem);

  /// \brief
  ///   Returns the root node of the menu.
  inline const VDefaultMenuListControlItem* GetRoot() const { return m_spRoot; }

  /// \brief
  ///   Returns the current active node of the menu.
  inline const VDefaultMenuListControlItem* GetCurrent() const { return m_spCurrent; }

  /// \brief
  ///   Return the currently selected item/group.
  inline const VDefaultMenuListControlItem* GetSelectedItem() const { return (VDefaultMenuListControlItem*)m_pListControl->GetSelectedItem(); }

  /// \brief
  ///   Returns whether the given item is a child of the given parent.
  bool IsChildOf(const VDefaultMenuListControlItem* pItem, const VDefaultMenuListControlItem* pParent) const;

  /// \brief
  ///   Refresh/Rebuild the current layout.
  void RefreshLayout();

  /// \brief
  ///   Start fade-in animation.
  void DoFadeIn();

  /// \brief
  ///   Start fade-out animation.
  void DoFadeOut(const VDialogState& followUpState);

  /// \brief
  ///   Sets the group icon which indicates the possibility of expanding a group (yellow arrow).
  inline void SetItemGroupIcon(VTextureObject* pTexture) { m_spItemGroup = pTexture; }

  /// \brief
  ///   Sets the icon which shows if an checkable item is currently activated or not (green dot).
  inline void SetItemActiveIcon(VTextureObject* pTexture) { m_spItemActive = pTexture; }

  /// \brief
  ///   Sets the vertical offset of the menu dialog to the upper screen boundary.
  inline void SetOffsetY(float fOffset) { m_fOffsetY = fOffset; }

  /// \brief
  ///   Returns the menu dialog's current scale.
  inline float GetScale() const { return m_fScale; }

  /// \brief
  ///   Sets the menu dialog's current scale.
  inline void SetScale(float fValue) { m_fScale = fValue; RefreshLayout(); }

  /// \brief
  ///   Resets everything to default.
  void Reset();

  /// \brief
  ///   Request a refresh of the list control on the next update.
  void RequestRefresh() { m_bIsDirty = true; }

private:
  void ProcessItemEvent(VDefaultMenuListControlItem* pItem);
  void AddItemToList(VDefaultMenuListControlItem* pItem);
  void BuildLabelText(VString& sLabelText);

  VDialogState m_state;
  VDialogState m_followUpState;
  float m_fTimer;
  VDefaultMenuListControlItem* m_pFutureItem;

  VisFontPtr m_spFont;

  static float s_fFadeTime;
  static const int s_iItemHeight = 34;
  static float s_fBorderWidth;
  static float s_fFontScale;

  VTextLabel* m_pLabel;
  VListControl* m_pListControl;
  VStyledButton* m_pCloseButton;

  VSmartPtr<VDefaultMenuListControlItem> m_spRoot;
  VSmartPtr<VDefaultMenuListControlItem> m_spCurrent;
  VSmartPtr<VDefaultMenuListControlItem> m_spBack;

  float m_fScale;
  float m_fOffsetY;

  VTextureObjectPtr m_spItemGroup;
  VTextureObjectPtr m_spItemActive;

  VMap<VInputMap*, bool> m_inputMapStates;

  bool m_bIsDirty;
};

/// \brief
///   Default menu implementation.
///
/// \ingroup VisionAppFramework
class VDefaultMenu : public VAppMenu
{
  V_DECLARE_DYNCREATE(VDefaultMenu);

public:
	VDefaultMenu();
	virtual ~VDefaultMenu() {}

  virtual void Init() HKV_OVERRIDE;
  virtual void DeInit() HKV_OVERRIDE;

  virtual void OnHandleCallback(IVisCallbackDataObject_cl* pData) HKV_OVERRIDE;

  virtual VisCallback_cl* RegisterItem(const VAppMenuItem& item, const char* szParentName = NULL) HKV_OVERRIDE;
  virtual VArray<VisCallback_cl*> RegisterGroup(const char* szGroupName, const VArray<VAppMenuItem>& items, const char* szParentName = NULL, unsigned int uiSortingKey = 0, bool bMultiSelect = true) HKV_OVERRIDE;

  virtual void RemoveItem(const char* szItemName) HKV_OVERRIDE;
  virtual void RemoveGroup(const char* szGroupName) HKV_OVERRIDE;

  virtual void SetItemCheckState(const char* szItemName, bool bActive) HKV_OVERRIDE;
  virtual bool GetItemCheckState(const char* szItemName) const HKV_OVERRIDE;

  virtual bool IsVisible() const HKV_OVERRIDE { return m_spDialog->IsVisible(); }
  virtual void SetVisible(bool bVisible) HKV_OVERRIDE { m_spDialog->SetVisible(bVisible); }
  virtual void ToggleMainMenu() HKV_OVERRIDE;

  virtual void Reset() HKV_OVERRIDE;

  /// \brief
  ///   Returns the dialog representing the default menu.
  VSmartPtr<VDefaultMenuDialog> GetDialog() { return m_spDialog; }

protected:
  void SetupIcon();
  void MapOpenMenuTouchArea();
  void UnmapOpenMenuTouchArea();

  VSmartPtr<VDefaultMenuDialog> m_spDialog;

  VisScreenMaskPtr m_spOpenMenuIcon;
  VisScreenMaskPtr m_spOpenMenuShortcutOverlay;

  int m_iOpenMenuTriggerAlternative;
};

#endif //__V_DEFAULT_MENU

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
