"""Generate the checked-in Xcode project with only Python's standard library."""
from pathlib import Path
import hashlib, json, plistlib, xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
objects = {}
def uid(key): return hashlib.sha1(key.encode()).hexdigest()[:24].upper()
def obj(key, isa, **values):
    identifier = uid(key); objects[identifier] = dict(isa=isa, **values); return identifier
def ref(path, kind='sourcecode.swift'):
    return obj('file:'+path, 'PBXFileReference', lastKnownFileType=kind, path=path, sourceTree='<group>')
def build_ref(target, file_ref): return obj('build:'+target+':'+file_ref, 'PBXBuildFile', fileRef=file_ref)
def config_list(name, settings, base):
    configs=[]
    for mode in ['Debug','Release']:
        config=dict(settings)
        config.update(SWIFT_OPTIMIZATION_LEVEL='-Onone' if mode=='Debug' else '-O', DEBUG_INFORMATION_FORMAT='dwarf' if mode=='Debug' else 'dwarf-with-dsym')
        if mode=='Debug': config.update(ENABLE_TESTABILITY='YES', SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG')
        configs.append(obj('config:'+name+mode,'XCBuildConfiguration',name=mode,buildSettings=config,baseConfigurationReference=base))
    return obj('configs:'+name,'XCConfigurationList',buildConfigurations=configs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')

(ROOT/'Config').mkdir(exist_ok=True)
base=ref('Config/Settings.xcconfig','text.xcconfig')
core=sorted(p.relative_to(ROOT).as_posix() for p in (ROOT/'Core').glob('*.swift'))
shared=sorted(p.relative_to(ROOT).as_posix() for p in (ROOT/'Shared').glob('*.swift'))
sources={
    'WordReview':core+shared+sorted(p.relative_to(ROOT).as_posix() for p in (ROOT/'App').glob('*.swift')),
    'WordReviewWidget':core+shared+['Widget/WordReviewWidget.swift'],
    'WordReviewTests':core+['Shared/PDFExtractor.swift','Shared/SharedStore.swift']+sorted(p.relative_to(ROOT).as_posix() for p in (ROOT/'Tests').rglob('*.swift')),
}
source_refs={path:ref(path) for path in sorted({s for paths in sources.values() for s in paths})}
resources={'WordReview':['App/Assets.xcassets','Config/PrivacyInfo.xcprivacy'], 'WordReviewWidget':['Config/PrivacyInfo.xcprivacy'], 'WordReviewTests':['Tests/Fixtures/table.pdf']}
resource_refs={s:ref(s,'folder.assetcatalog' if s.endswith('xcassets') else 'text.xml' if s.endswith('xcprivacy') else 'image.pdf') for paths in resources.values() for s in paths}
products={}
for name,ext,kind in [('WordReview','app','wrapper.application'),('WordReviewWidget','appex','wrapper.app-extension'),('WordReviewTests','xctest','wrapper.cfbundle')]:
    products[name]=obj('product:'+name,'PBXFileReference',explicitFileType=kind,includeInIndex=0,path=name+'.'+ext,sourceTree='BUILT_PRODUCTS_DIR')
product_group=obj('products','PBXGroup',children=list(products.values()),name='Products',sourceTree='<group>')
other_refs=[base]+[ref('Config/'+s,'text.plist.xml') for s in ['App-Info.plist','Widget-Info.plist','App.entitlements','Widget.entitlements']]
main_group=obj('main','PBXGroup',children=list(source_refs.values())+list(resource_refs.values())+other_refs+[product_group],sourceTree='<group>')
project_settings=dict(SWIFT_VERSION='5.0',IPHONEOS_DEPLOYMENT_TARGET='17.0',SDKROOT='iphoneos',TARGETED_DEVICE_FAMILY='1,2',CLANG_ENABLE_MODULES='YES',CLANG_ENABLE_OBJC_ARC='YES',SWIFT_STRICT_CONCURRENCY='minimal',CODE_SIGN_STYLE='Automatic',SUPPORTED_PLATFORMS='iphoneos iphonesimulator')
project_configs=config_list('project',project_settings,base)
target_ids={name:uid('target:'+name) for name in sources}
proxy=obj('widget-proxy','PBXContainerItemProxy',containerPortal=uid('project'),proxyType=1,remoteGlobalIDString=target_ids['WordReviewWidget'],remoteInfo='WordReviewWidget')
dependency=obj('widget-dependency','PBXTargetDependency',target=target_ids['WordReviewWidget'],targetProxy=proxy)
embed_file=obj('embed-widget','PBXBuildFile',fileRef=products['WordReviewWidget'],settings={'ATTRIBUTES':['RemoveHeadersOnCopy']})
embed_phase=obj('embed-widgets','PBXCopyFilesBuildPhase',buildActionMask=2147483647,dstPath='',dstSubfolderSpec=13,files=[embed_file],name='Embed App Extensions',runOnlyForDeploymentPostprocessing=0)
for name, paths in sources.items():
    phases=[obj('sources:'+name,'PBXSourcesBuildPhase',buildActionMask=2147483647,files=[build_ref(name,source_refs[s]) for s in paths],runOnlyForDeploymentPostprocessing=0),
            obj('frameworks:'+name,'PBXFrameworksBuildPhase',buildActionMask=2147483647,files=[],runOnlyForDeploymentPostprocessing=0),
            obj('resources:'+name,'PBXResourcesBuildPhase',buildActionMask=2147483647,files=[build_ref(name,resource_refs[s]) for s in resources[name]],runOnlyForDeploymentPostprocessing=0)]
    settings=dict(PRODUCT_NAME='$(TARGET_NAME)',CURRENT_PROJECT_VERSION='1',MARKETING_VERSION='0.1.0',LD_RUNPATH_SEARCH_PATHS=['$(inherited)','@executable_path/Frameworks'])
    if name=='WordReview':
        settings.update(PRODUCT_BUNDLE_IDENTIFIER='$(APP_BUNDLE_ID)',INFOPLIST_FILE='Config/App-Info.plist',CODE_SIGN_ENTITLEMENTS='Config/App.entitlements',ASSETCATALOG_COMPILER_APPICON_NAME='AppIcon')
        phases.append(embed_phase)
    elif name=='WordReviewWidget':
        settings.update(PRODUCT_BUNDLE_IDENTIFIER='$(APP_BUNDLE_ID).widget',INFOPLIST_FILE='Config/Widget-Info.plist',CODE_SIGN_ENTITLEMENTS='Config/Widget.entitlements',SKIP_INSTALL='YES',APPLICATION_EXTENSION_API_ONLY='YES',LD_RUNPATH_SEARCH_PATHS=['$(inherited)','@executable_path/Frameworks','@executable_path/../../Frameworks'])
    else:
        settings.update(PRODUCT_BUNDLE_IDENTIFIER='$(APP_BUNDLE_ID).tests',GENERATE_INFOPLIST_FILE='YES',SKIP_INSTALL='YES')
    obj('target:'+name,'PBXNativeTarget',name=name,productName=name,productReference=products[name],productType='com.apple.product-type.application' if name=='WordReview' else 'com.apple.product-type.app-extension' if name=='WordReviewWidget' else 'com.apple.product-type.bundle.unit-test',buildConfigurationList=config_list(name,settings,base),buildPhases=phases,buildRules=[],dependencies=[dependency] if name=='WordReview' else [])
obj('project','PBXProject',attributes={'LastUpgradeCheck':'1600','TargetAttributes':{target_ids[n]:{'CreatedOnToolsVersion':'16.0','SystemCapabilities':{'com.apple.ApplicationGroups.iOS':{'enabled':1}}} for n in ['WordReview','WordReviewWidget']}},buildConfigurationList=project_configs,compatibilityVersion='Xcode 14.0',developmentRegion='zh-Hans',hasScannedForEncodings=0,knownRegions=['en','Base','zh-Hans'],mainGroup=main_group,productRefGroup=product_group,projectDirPath='',projectRoot='',targets=list(target_ids.values()))
def openstep(value, level=0):
    indent='\t'*level
    if isinstance(value,dict):return '{\n'+''.join(indent+'\t'+json.dumps(k,ensure_ascii=False)+' = '+openstep(v,level+1)+';\n' for k,v in value.items())+indent+'}'
    if isinstance(value,list):return '(\n'+''.join(indent+'\t'+openstep(v,level+1)+',\n' for v in value)+indent+')'
    if isinstance(value,int):return str(value)
    return json.dumps(value,ensure_ascii=False)
project=ROOT/'WordReview.xcodeproj';project.mkdir(exist_ok=True)
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n'+openstep({'archiveVersion':1,'classes':{},'objectVersion':56,'objects':objects,'rootObject':uid('project')})+'\n',encoding='utf-8')
scheme=ET.Element('Scheme',LastUpgradeVersion='1600',version='1.3')
action=ET.SubElement(scheme,'BuildAction',parallelizeBuildables='YES',buildImplicitDependencies='YES');entries=ET.SubElement(action,'BuildActionEntries')
def buildable(parent,name):
    ET.SubElement(parent,'BuildableReference',BuildableIdentifier='primary',BlueprintIdentifier=target_ids[name],BuildableName=name+('.app' if name=='WordReview' else '.xctest'),BlueprintName=name,ReferencedContainer='container:WordReview.xcodeproj')
for name in ['WordReview','WordReviewTests']:
    entry=ET.SubElement(entries,'BuildActionEntry',buildForTesting='YES',buildForRunning='YES' if name=='WordReview' else 'NO',buildForProfiling='YES' if name=='WordReview' else 'NO',buildForArchiving='YES' if name=='WordReview' else 'NO',buildForAnalyzing='YES');buildable(entry,name)
test=ET.SubElement(scheme,'TestAction',buildConfiguration='Debug',selectedDebuggerIdentifier='Xcode.DebuggerFoundation.Debugger.LLDB',selectedLauncherIdentifier='Xcode.IDEFoundation.Launcher.LLDB',shouldUseLaunchSchemeArgsEnv='YES');tests=ET.SubElement(test,'Testables');buildable(ET.SubElement(tests,'TestableReference',skipped='NO'),'WordReviewTests')
launch=ET.SubElement(scheme,'LaunchAction',buildConfiguration='Debug',selectedDebuggerIdentifier='Xcode.DebuggerFoundation.Debugger.LLDB',selectedLauncherIdentifier='Xcode.IDEFoundation.Launcher.LLDB',launchStyle='0',useCustomWorkingDirectory='NO',ignoresPersistentStateOnLaunch='NO',debugDocumentVersioning='YES',debugServiceExtension='internal',allowLocationSimulation='YES');buildable(ET.SubElement(launch,'BuildableProductRunnable',runnableDebuggingMode='0'),'WordReview')
ET.SubElement(scheme,'AnalyzeAction',buildConfiguration='Debug');ET.SubElement(scheme,'ArchiveAction',buildConfiguration='Release',revealArchiveInOrganizer='YES')
schemes=project/'xcshareddata/xcschemes';schemes.mkdir(parents=True,exist_ok=True);ET.indent(scheme);ET.ElementTree(scheme).write(schemes/'WordReview.xcscheme',encoding='utf-8',xml_declaration=True)
common={'CFBundleDevelopmentRegion':'zh-Hans','CFBundleDisplayName':'词页复习','CFBundleExecutable':'$(EXECUTABLE_NAME)','CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)','CFBundleInfoDictionaryVersion':'6.0','CFBundleName':'$(PRODUCT_NAME)','CFBundleShortVersionString':'$(MARKETING_VERSION)','CFBundleVersion':'$(CURRENT_PROJECT_VERSION)','ReviewAppGroup':'$(APP_GROUP_IDENTIFIER)','ReviewRefreshIdentifier':'$(REVIEW_REFRESH_IDENTIFIER)'}
app=dict(common,CFBundlePackageType='APPL',LSRequiresIPhoneOS=True,UILaunchScreen={},UIApplicationSceneManifest={'UIApplicationSupportsMultipleScenes':False},UISupportedInterfaceOrientations=['UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],UIBackgroundModes=['fetch'],BGTaskSchedulerPermittedIdentifiers=['$(REVIEW_REFRESH_IDENTIFIER)'],CFBundleURLTypes=[{'CFBundleURLName':'WordReview','CFBundleURLSchemes':['wordreview']}],ITSAppUsesNonExemptEncryption=False)
widget=dict(common,CFBundlePackageType='XPC!',NSExtension={'NSExtensionPointIdentifier':'com.apple.widgetkit-extension'})
for name,data in [('App-Info.plist',app),('Widget-Info.plist',widget),('App.entitlements',{'com.apple.security.application-groups':['$(APP_GROUP_IDENTIFIER)']}),('Widget.entitlements',{'com.apple.security.application-groups':['$(APP_GROUP_IDENTIFIER)']}),('PrivacyInfo.xcprivacy',{'NSPrivacyTracking':False,'NSPrivacyTrackingDomains':[],'NSPrivacyCollectedDataTypes':[],'NSPrivacyAccessedAPITypes':[]})]:
    (ROOT/'Config'/name).write_bytes(plistlib.dumps(data,sort_keys=False))
print('Generated WordReview.xcodeproj: app, widget extension, iOS tests.')
