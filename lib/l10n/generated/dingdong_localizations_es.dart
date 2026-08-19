// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'dingdong_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class DingDongLocalizationsEs extends DingDongLocalizations {
  DingDongLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get languageEnglish => 'Inglés';

  @override
  String get languageChinese => 'Chino';

  @override
  String get languageSpanish => 'Español';

  @override
  String get aNewVersionIsAvailable => 'Una nueva versión está disponible';

  @override
  String aSelectedLocalPathResourceCouldNotBeSharedError(Object error) {
    return 'No se pudo compartir un recurso de ruta local seleccionado: $error';
  }

  @override
  String
  get aSkillMeansItsFullInstructionsWereLoadedForThisTaskAnMCP_240facd9 =>
      'Un Skill * significa que se cargaron sus instrucciones completas para esta tarea. Un MCP * significa que se llamó a una de sus herramientas, no que la llamada se realizó correctamente. Los Prompts permanecen sin marcar.';

  @override
  String get aToolConnectionWhoseMCPToolsAreCalledOnlyWhenTheTask_08282426 =>
      'Una conexión de herramienta cuyas herramientas MCP se llaman solo cuando la tarea las requiere.';

  @override
  String actionCountTimes(Object action, Object count, Object times) {
    return '$action $count $times';
  }

  @override
  String get activated => 'Activado';

  @override
  String get activated2 => 'activado';

  @override
  String get adapterVersionHistory => 'Historial de versiones del adaptador';

  @override
  String get addALocalNoteAboutHowYouUseThisSkill =>
      'Agregue una nota local sobre cómo usa este Skill.';

  @override
  String get addAgentConfiguration => 'Agregar configuración agent';

  @override
  String get addAtLeastOneCompleteRule =>
      'Agregue al menos una regla completa.';

  @override
  String get addOneOrMoreExistingAbsoluteProjectDirectories =>
      'Agregue uno o más directorios absolutos de proyectos existentes.';

  @override
  String get addProject => 'Agregar proyecto';

  @override
  String get addRule => 'Agregar regla';

  @override
  String get addTitle => 'Agregar título';

  @override
  String get addToGroups => 'Agregar a grupos';

  @override
  String get advancedAPIAndMCPDetails => 'Detalles avanzados de API y MCP';

  @override
  String get advancedCommandsAndTheInstallationPromptTheirPresence_b84b4903 =>
      'Comandos avanzados e instalación prompt. Su presencia no significa que se haya verificado un Agent.';

  @override
  String get advancedMatching => 'Emparejamiento avanzado';

  @override
  String get afterTheGlobalShortcutDingDongCanReturnFocusAndPasteThe_5ad1a82a =>
      'Después del acceso directo global, DingDong puede volver a centrarse y pegar el elemento seleccionado.';

  @override
  String
  get afterUpdatingYouWillNeedToGrantDingDongSMacOSPermissions_20660ff5 =>
      'Después de la actualización, deberá otorgar permisos a macOS de DingDong nuevamente en Configuración del sistema.';

  @override
  String get agentActivity => 'Actividad Agent';

  @override
  String get agentAlerts => 'Alertas Agent';

  @override
  String get agentAndClipboardItemsCreatedHereAreExplicitDEVTestData_f8625f9f =>
      'Agent y los elementos del portapapeles creados aquí son datos de prueba DEV explícitos. Las muestras de origen del teléfono son simulaciones, nunca capturadas desde el portapapeles de un teléfono real.';

  @override
  String get agentCompletion => 'Agent finalización';

  @override
  String get agentCompletionNotifications =>
      'Notificaciones de finalización de Agent';

  @override
  String agentCompletionNotificationsForName(Object name) {
    return 'Notificaciones de finalización de Agent para $name';
  }

  @override
  String get agentCompletionSignal => 'Señal de finalización Agent';

  @override
  String get agentConfigurationFileIsInvalid =>
      'El archivo de configuración Agent no es válido';

  @override
  String get agentConnectionCenter => 'Centro de conexión Agent';

  @override
  String get agentConnections => 'Conexiones Agent';

  @override
  String get agentDecides => 'Agent decide';

  @override
  String get agentPluginProvidesTheSameSkill =>
      'El complemento Agent proporciona el mismo Skill';

  @override
  String get agentReplyFooter => 'Pie de página de respuesta Agent';

  @override
  String get agentResourceSyncFailed =>
      'Error en la sincronización de recursos Agent';

  @override
  String get agentSessionLoadingName => 'Agent nombre de carga de sesión';

  @override
  String get agentSetupNeedsUpdate =>
      'La configuración de Agent necesita actualización';

  @override
  String get agentSetupPrompt => 'Agent configuración prompt';

  @override
  String get agentSetupPromptNeedsUpdating =>
      'Configuración de Agent prompt necesita actualización';

  @override
  String get agentSource => 'fuente Agent';

  @override
  String get all => 'Todo';

  @override
  String get allProjectsNoRestriction =>
      'Todos los proyectos · sin restricciones';

  @override
  String get allSources => 'Todas las fuentes';

  @override
  String get allowAgentsToReadClipboardContent =>
      'Permitir que Agents lea el contenido del portapapeles';

  @override
  String get allowedByTheExplicitSettingsSwitch =>
      'Permitido por el interruptor de Configuración explícito';

  @override
  String get always => 'Siempre';

  @override
  String get anEnabledAgentPluginProvidesASkillWithTheSameNameBoth_c5e2f5ee =>
      'Un complemento Agent habilitado proporciona un Skill con el mismo nombre. Ambos siguen disponibles; revisar cuál se debe utilizar.';

  @override
  String get anExistingUserManagedSkillWasPreservedDingDongDidNot_0f7d7c2a =>
      'Se conservó un Skill existente administrado por el usuario. DingDong no lo sobrescribió.';

  @override
  String get anonymousInstallAndUpdateStatistics =>
      'Estadísticas anónimas de instalación y actualización';

  @override
  String get apiAgentConnections => 'API | Conexiones Agent';

  @override
  String apiListeningOnHostPort(Object host, Object port) {
    return 'API escuchando en $host:$port';
  }

  @override
  String get apiStatusUnverified => 'Estado API no verificado';

  @override
  String get appearance => 'Apariencia';

  @override
  String get applicationConfiguration => 'Configuración de la aplicación';

  @override
  String get apply => 'Aplicar';

  @override
  String get archiveTo => 'Archivar en…';

  @override
  String get archiveToGroups => 'Archivar en grupos';

  @override
  String get archivedCopiesRemainUnchanged =>
      'Las copias archivadas permanecen sin cambios.';

  @override
  String get argumentsOnePerLine => 'Argumentos · uno por línea';

  @override
  String get autoSendClipboard => 'Portapapeles de envío automático';

  @override
  String autoSendClipboardFromThisComputerToName(Object name) {
    return 'Envío automático del portapapeles desde esta computadora a $name';
  }

  @override
  String get availableToInstalledAgents => 'Disponible para Agents instalado';

  @override
  String get backToCategories => 'Volver a categorías';

  @override
  String get backToDynamic => 'Volver a Dinámico';

  @override
  String get backToResources => 'Volver a recursos';

  @override
  String get backToTop => 'Volver arriba';

  @override
  String get basicCompletion => 'Finalización básica';

  @override
  String get bearerTokenEnv => 'Portador token entorno';

  @override
  String get blue => 'Azul';

  @override
  String get called => 'Llamado';

  @override
  String get called2 => 'llamado';

  @override
  String get cancel => 'Cancelar';

  @override
  String get cancelDevicePairing =>
      'Cancelar el emparejamiento del dispositivo';

  @override
  String get cancelPairing => 'Cancelar emparejamiento';

  @override
  String get candidate => 'Candidato';

  @override
  String get captureCurrentClipboard => 'Capturar el portapapeles actual';

  @override
  String get captureNow => 'Capturar ahora';

  @override
  String get captureTextFilesAndImagesWhileDingDongIsRunning =>
      'Capture texto, archivos e imágenes mientras se ejecuta DingDong.';

  @override
  String get caseSensitive => 'Distingue mayúsculas y minúsculas';

  @override
  String get category => 'Categoría';

  @override
  String get categoryName => 'Nombre de categoría';

  @override
  String get categoryNameIsRequired =>
      'El nombre de la categoría es obligatorio.';

  @override
  String get categoryRule => 'regla de categoría';

  @override
  String get check => 'Controlar';

  @override
  String get check2 => 'Controlar';

  @override
  String get check3 => 'Controlar';

  @override
  String get checkUnreadCountingOrderingAndRepeatedPhoneDelivery =>
      'Verifique el conteo no leído, los pedidos y las entregas telefónicas repetidas.';

  @override
  String get checkUpdate => 'comprobar actualización';

  @override
  String get checking => 'De cheques';

  @override
  String get checkingForUpdates => 'Buscando actualizaciones...';

  @override
  String get checkingLocalService => 'Comprobando el servicio local';

  @override
  String get choose => 'Elegir';

  @override
  String get chooseHowDingDongBehavesWhenYouSignIn =>
      'Elija cómo se comporta DingDong cuando inicia sesión.';

  @override
  String get chooseRules => 'Elige reglas';

  @override
  String get chooseWhichAgentEventsShouldNotifyYouThenCustomizeThe_7d9141e4 =>
      'Elija qué eventos Agent deben notificarle y luego personalice el sonido y el color de la alerta.';

  @override
  String get clean => 'Limpio';

  @override
  String get clear => 'Claro';

  @override
  String get clearAll => 'Borrar todo';

  @override
  String clearCategory(Object category) {
    return '¿Borrar $category?';
  }

  @override
  String get clearCustomSound => 'Sonido personalizado claro';

  @override
  String get clearSearch => 'Borrar búsqueda';

  @override
  String get clearSelection => 'Borrar selección';

  @override
  String get clearSelection2 => 'Borrar selección';

  @override
  String get clickAnywhereToCloseEsc =>
      'Haga clic en cualquier lugar para cerrar · Esc';

  @override
  String get clickToEnlargeQRCode => 'Haga clic para ampliar el código QR';

  @override
  String get clipboard => 'Portapapeles';

  @override
  String get clipboardAndDevices => 'Portapapeles y dispositivos';

  @override
  String get clipboardBodyAccess => 'Acceso al cuerpo del portapapeles';

  @override
  String get clipboardCategories => 'Categorías del portapapeles';

  @override
  String get clipboardContent => 'Contenido del portapapeles';

  @override
  String
  get clipboardContentStaysMetadataOnlyUnlessExplicitlyEnabled_df1d930e =>
      'El contenido del portapapeles sigue siendo solo metadatos a menos que se habilite explícitamente en Configuración.';

  @override
  String get clipboardDatabase => 'Base de datos del portapapeles';

  @override
  String get clipboardDetailsAndCompleteContent =>
      'Detalles del portapapeles y contenido completo';

  @override
  String get clipboardHistory => 'Historial del portapapeles';

  @override
  String get clipboardHistory2 => 'Historial del portapapeles';

  @override
  String get clipboardHistoryRemainsUnchanged =>
      'El historial del portapapeles permanece sin cambios.';

  @override
  String get clipboardItem => 'Elemento del portapapeles.';

  @override
  String clipboardSortLabel(Object label) {
    return 'Clasificación del portapapeles: $label';
  }

  @override
  String get clipboardWorkspace => 'Espacio de trabajo del portapapeles';

  @override
  String get clipboardWorkspaceShortcut =>
      'Acceso directo al espacio de trabajo del portapapeles';

  @override
  String get close => 'Cerca';

  @override
  String get closeEnlargedView => 'Cerrar vista ampliada';

  @override
  String get code => 'Código';

  @override
  String get codexSubagent => 'Subagente Codex';

  @override
  String get codexVoiceTaskNotifications =>
      'Codex notificaciones de tareas de voz';

  @override
  String get command => 'Dominio';

  @override
  String get command2 => 'Dominio';

  @override
  String get completionDetailsStayOnThisDeviceCountingMetadata_9920ce29 =>
      'Los detalles de finalización permanecen en este dispositivo. Los metadatos de conteo solo contienen marcas de tiempo.';

  @override
  String get completionHistoryAndRecentCounts =>
      'Historial de finalización y recuentos recientes';

  @override
  String get completionNotificationsAreOffForThisDevice =>
      'Las notificaciones de finalización están desactivadas para este dispositivo';

  @override
  String get configurationDetails => 'Detalles de configuración';

  @override
  String get configurationSaved => 'Configuración guardada';

  @override
  String get configureProjects => 'Configurar proyectos';

  @override
  String
  get configureTheFinalDingDongResourceLineAndOptionallyAppend_e6f7cb62 =>
      'Configure la línea de recursos DingDong final y, opcionalmente, agregue el uso exacto de la sesión.';

  @override
  String get connectANewDevice => 'Conectar un nuevo dispositivo';

  @override
  String get connectedDevices => 'Dispositivos conectados';

  @override
  String get connecting => 'Conectando…';

  @override
  String get connection => 'Conexión';

  @override
  String get connectionError => 'Error de conexión';

  @override
  String get connectionManager => 'Administrador de conexión';

  @override
  String connectionTestFailedError(Object error) {
    return 'La prueba de conexión falló: $error';
  }

  @override
  String get connectionType => 'Tipo de conexión';

  @override
  String get contains => 'Contiene';

  @override
  String get contains2 => 'contiene';

  @override
  String get content => 'Contenido';

  @override
  String get contentQRCode => 'Código QR de contenido';

  @override
  String get contentRegex => 'Expresión regular de contenido';

  @override
  String get contentRegularExpression => 'Expresión regular de contenido';

  @override
  String get contentType => 'tipo de contenido';

  @override
  String get contentTypes => 'Tipos de contenido';

  @override
  String get copied => 'copiado';

  @override
  String copiedCountTimes(Object count) {
    return 'Copiado $count veces';
  }

  @override
  String get copiedFileReferencesOriginalFilesAreNeverDeleted =>
      'Referencias de archivos copiados; Los archivos originales nunca se eliminan.';

  @override
  String get copy => 'Copiar';

  @override
  String get copyContent => 'Copiar contenido';

  @override
  String get copyCount => 'Recuento de copias';

  @override
  String get copyCount2 => 'Recuento de copias';

  @override
  String get coreEndpoints => 'Puntos finales principales';

  @override
  String couldNotApplyThisSkillDeliveryPolicyDetail(Object detail) {
    return 'No se pudo aplicar esta política de entrega Skill. $detail';
  }

  @override
  String couldNotFetchThisUpdateError(Object error) {
    return 'No se pudo recuperar esta actualización: $error';
  }

  @override
  String couldNotImportThisResourceBundleError(Object error) {
    return 'No se pudo importar este paquete de recursos: $error';
  }

  @override
  String get couldNotOpenThisAgentConversation =>
      'No se pudo abrir esta conversación Agent.';

  @override
  String get couldNotOpenThisSkillSource =>
      'No se pudo abrir esta fuente Skill.';

  @override
  String get couldNotReachTheSourceCheckYourNetworkAndLinkThenTry_1c1ff9ae =>
      'No se pudo llegar a la fuente. Verifique su red y enlace, luego intente nuevamente.';

  @override
  String get couldNotSaveThisConfigurationCheckTheContentAndTryAgain =>
      'No se pudo guardar esta configuración. Comprueba el contenido y vuelve a intentarlo.';

  @override
  String couldNotSyncThisResourceToAnInstalledAgentDetail(Object detail) {
    return 'No se pudo sincronizar este recurso con un Agent instalado. $detail';
  }

  @override
  String countIssuesNeedAttention(Object count) {
    return 'Los problemas de $count necesitan atención';
  }

  @override
  String countItems(Object count) {
    return 'Artículos $count';
  }

  @override
  String countItemsDescription(Object count, Object description) {
    return '$count artículos · $description';
  }

  @override
  String countPairedDevices(Object count) {
    return 'Dispositivos emparejados $count';
  }

  @override
  String countSelected(Object count) {
    return '$count seleccionado';
  }

  @override
  String get countWindowHours => 'Ventana de conteo (horas)';

  @override
  String get create => 'Crear';

  @override
  String
  get createAComputerRecordAndSendItOnlyToConnectedDevicesWith_41a63724 =>
      'Cree un registro de computadora y envíelo solo a dispositivos conectados con el envío automático habilitado.';

  @override
  String get createAQRCodeThenScanItWithTheDeviceYouTrust =>
      'Cree un código QR y luego escanéelo con el dispositivo de su confianza.';

  @override
  String get createASampleAndOpenTheRealTargetDeviceChooser =>
      'Cree una muestra y abra el selector de dispositivo de destino real.';

  @override
  String get createAndSend => 'Crear y enviar';

  @override
  String get createOneClearlyLabeledDEVCompletion =>
      'Cree una finalización DEV claramente etiquetada.';

  @override
  String get createOneToStartOrganizingClipboardItems =>
      'Cree uno para comenzar a organizar los elementos del portapapeles.';

  @override
  String get createResource => 'Crear recurso';

  @override
  String get createdBasicAgentCompletion =>
      'Creado: finalización básica de Agent';

  @override
  String get createdComputerAutoSendSample =>
      'Creado: muestra de envío automático por computadora';

  @override
  String get createdRichMobileAgentDetail => 'Creado: rico detalle móvil Agent';

  @override
  String get createdSimulatedPhoneFileRow =>
      'Creado: fila de archivos de teléfono simulada';

  @override
  String get createdSimulatedPhoneTextRow =>
      'Creado: fila de texto de teléfono simulado';

  @override
  String get createdThreeAgentCompletions =>
      'Creado: tres finalizaciones Agent';

  @override
  String get createsRemovableDEVSamplesOrOpensTheRealDeviceWorkflow =>
      'Crea muestras DEV extraíbles o abre el flujo de trabajo del dispositivo real.';

  @override
  String get curatedContentReusableByAgents =>
      'Contenido curado reutilizable por agents';

  @override
  String get current => 'Actual';

  @override
  String get currentAgentAccessClipboardRulesAndRuntimeState =>
      'Acceso actual a Agent, reglas del portapapeles y estado de tiempo de ejecución';

  @override
  String get currentMemory => 'Memoria actual';

  @override
  String get cursorCompatibleFormat => 'Formato compatible con Cursor';

  @override
  String get customFile => 'Archivo personalizado';

  @override
  String get customSound => 'Sonido personalizado';

  @override
  String get dark => 'Oscuro';

  @override
  String get defaultOrder => 'Orden predeterminado';

  @override
  String get defaultWorkspace => 'Espacio de trabajo predeterminado';

  @override
  String get defineWhatContentBelongsInThisCategory =>
      'Defina qué contenido pertenece a esta categoría.';

  @override
  String get delete => 'Borrar';

  @override
  String get deleteCategory => 'Eliminar categoría';

  @override
  String get deleteGroup => 'Eliminar grupo';

  @override
  String deleteGroup2(Object group) {
    return '¿Eliminar “$group”?';
  }

  @override
  String deleteName(Object name) {
    return '¿Eliminar “$name”?';
  }

  @override
  String get deleteSelectedItems => '¿Eliminar elementos seleccionados?';

  @override
  String get deleteSelectedResources => '¿Eliminar los recursos seleccionados?';

  @override
  String get deleteThisArchivedCopy => '¿Eliminar esta copia archivada?';

  @override
  String get deleteThisCategory => '¿Eliminar esta categoría?';

  @override
  String get deleteThisClipboardItem =>
      '¿Eliminar este elemento del portapapeles?';

  @override
  String get deleteThisDevice => '¿Eliminar este dispositivo?';

  @override
  String get deleteThisResource => '¿Eliminar este recurso?';

  @override
  String get deleteThisResource2 => '¿Eliminar este recurso?';

  @override
  String get deletedHistoryCannotBeRestored =>
      'El historial eliminado no se puede restaurar.';

  @override
  String get deliveryByAgent => 'Entrega por Agent';

  @override
  String get describeTheBehaviorTheAgentShouldFollow =>
      'Describe el comportamiento que debe seguir el Agent.';

  @override
  String get desktopBehaviorHistoryPrivacyAndLocalAgentConnectivity =>
      'Comportamiento del escritorio, privacidad del historial y conectividad agent local.';

  @override
  String get desktopNotification => 'Notificación de escritorio';

  @override
  String get details => 'Detalles';

  @override
  String get dingdongBright => 'DingDong Brillante';

  @override
  String
  get dingdongChecksAutomaticallyWhenResourcesChangeUseCheckIn_ab07f57c =>
      'DingDong comprueba automáticamente cuando cambian los recursos. Utilice Check en la esquina superior derecha para ejecutarlo nuevamente.';

  @override
  String get dingdongClassic => 'DingDong Clásico';

  @override
  String get dingdongCopiesTheCompleteSkillPackageIntoEachSelected_de26f089 =>
      'DingDong copia el paquete Skill completo en el directorio nativo de cada proyecto seleccionado. El Skill se descubre solo cuando ese Agent funciona en el proyecto.';

  @override
  String get dingdongCrisp => 'DingDong Crujiente';

  @override
  String dingdongCurrentAppVersionDesktop(Object currentAppVersion) {
    return 'DingDong $currentAppVersion · Escritorio';
  }

  @override
  String get dingdongDeep => 'DingDong Profundo';

  @override
  String get dingdongDeviceConnectionManager =>
      'Administrador de conexión de dispositivos DingDong';

  @override
  String dingdongHasRecordedTheseLocalStatisticsSinceDateEarlier_90d48aa0(
    Object date,
  ) {
    return 'DingDong ha registrado estas estadísticas locales desde $date. La actividad anterior no se repone, por lo que 0 no significa necesariamente que este recurso nunca se haya utilizado.';
  }

  @override
  String get dingdongListensOnlyOnTheLocalLoopbackInterface =>
      'DingDong escucha sólo en la interfaz de loopback local.';

  @override
  String get dingdongOwnedImageCopiesAndRecords =>
      'Copias y registros de imágenes propiedad de DingDong';

  @override
  String
  get dingdongPreservedTheExistingAgentFileBecauseItCouldNotBe_6c5484e5 =>
      'DingDong conservó el archivo Agent existente porque no se pudo analizar de forma segura.';

  @override
  String get dingdongResourceManagerWindow =>
      'Ventana del administrador de recursos DingDong';

  @override
  String get dingdongSettingsWindow => 'Ventana de configuración DingDong';

  @override
  String get dingdongSkillsUseTheSameName =>
      'Los Skills de DingDong usan el mismo nombre';

  @override
  String get dingdongSoft => 'DingDong Suave';

  @override
  String get disable => 'Desactivar';

  @override
  String get disableCategory => 'Desactivar categoría';

  @override
  String get disableResource => 'Deshabilitar recurso';

  @override
  String get discardChanges => 'Descartar cambios';

  @override
  String get discardUnsavedChanges => '¿Descartar los cambios no guardados?';

  @override
  String get disconnect => 'Desconectar';

  @override
  String get downloadingUpdate => 'Descargando actualización…';

  @override
  String downloadingUpdatePercent(Object percent) {
    return 'Descargando actualización… $percent%';
  }

  @override
  String get dynamicLoadsOnDemandThroughDingDongNativeGlobalInstalls_ff4bd6e5 =>
      'Cargas dinámicas bajo demanda a través de DingDong. Nativo · Instalaciones globales en el directorio de usuarios Agent. Nativo · El proyecto se instala sólo en proyectos seleccionados.';

  @override
  String get dynamicMessage => 'Dinámica';

  @override
  String get dynamicWorkspace => 'Espacio de trabajo dinámico';

  @override
  String get dynamicWorkspaceShortcut =>
      'Acceso directo al espacio de trabajo dinámico';

  @override
  String get eGConciseReleaseNotes => 'p.ej. Notas de versión concisas';

  @override
  String get eGDingDongProjects => 'p.ej. Proyectos DingDong';

  @override
  String get eGFigma => 'p.ej. figura';

  @override
  String get eGProjectDrafts => 'p.ej. Borradores de proyectos';

  @override
  String get eachProjectMustBeAnExistingAbsoluteDirectory =>
      'Cada proyecto debe ser un directorio absoluto existente.';

  @override
  String get edit => 'Editar';

  @override
  String get editAndOrganize => 'Editar y organizar';

  @override
  String get editProjectGroup => 'Editar grupo de proyectos';

  @override
  String get editRules => 'Editar reglas';

  @override
  String get editText => 'Editar texto';

  @override
  String get editTitle => 'Editar título';

  @override
  String get editTriggerGroup => 'Editar grupo de activadores';

  @override
  String get email => 'Correo electrónico';

  @override
  String get enable => 'Permitir';

  @override
  String get enableCategory => 'Habilitar categoría';

  @override
  String get enableResource => 'Habilitar recurso';

  @override
  String get enableResourcesFromTheLibraryToSeeThemHere =>
      'Habilite recursos de la biblioteca para verlos aquí.';

  @override
  String get enabled => 'Activado';

  @override
  String get enabled2 => 'Activado';

  @override
  String get enabledPhoneVibrationIsOff =>
      'Habilitado · La vibración del teléfono está desactivada';

  @override
  String get enabledPhoneVibrationIsOn =>
      'Habilitado · La vibración del teléfono está activada';

  @override
  String get endpointsCommandsAndSetupPrompt =>
      'Puntos finales, comandos y configuración prompt';

  @override
  String get enlargeQRCode => 'Ampliar código QR';

  @override
  String get enterATriggerGroupName =>
      'Introduzca un nombre de grupo de activación.';

  @override
  String get enterAValidWebSourceBeforeOpeningIt =>
      'Ingrese una fuente web válida antes de abrirla.';

  @override
  String get enterOneVisibleSymbolAsteriskAndVerticalBarAreReserved =>
      'Introduzca un símbolo visible. El asterisco y la barra vertical están reservados.';

  @override
  String get environment => 'Ambiente';

  @override
  String get equals => 'igual';

  @override
  String get equals2 => 'es igual';

  @override
  String get executablePathNpxUvx => 'Ruta ejecutable, npx, uvx…';

  @override
  String get exerciseRealDingDongIntegrationPathsFromOnePlace =>
      'Ejercite rutas de integración reales de DingDong desde un solo lugar.';

  @override
  String get exportJSON => 'Exportar JSON';

  @override
  String exportedResourceLibraryToPath(Object path) {
    return 'Biblioteca de recursos exportada a $path';
  }

  @override
  String get fetchAndReview => 'Buscar y revisar';

  @override
  String get fetchLatestContent => 'Obtener el contenido más reciente';

  @override
  String get file => 'Archivo';

  @override
  String get fileFromPhone => 'Archivo desde el teléfono';

  @override
  String get fileHistory => 'Historial de archivos';

  @override
  String get files => 'Archivos';

  @override
  String get findIcon => 'icono de búsqueda';

  @override
  String get forExampleProjectLinks => 'Por ejemplo: enlaces de proyectos';

  @override
  String get general => 'General';

  @override
  String get gotIt => 'Entiendo';

  @override
  String get green => 'Verde';

  @override
  String get group => 'Grupo';

  @override
  String get groupName => 'Nombre del grupo';

  @override
  String get groupRepeatedSessions => 'Sesiones repetidas en grupo.';

  @override
  String get groups => 'Grupos';

  @override
  String get groups2 => 'Grupos';

  @override
  String get headers => 'Encabezados';

  @override
  String get healthCheckFailed => 'Error en el control de salud';

  @override
  String get healthCheckPassed => 'Chequeo de salud pasado';

  @override
  String get hideCategoriesAndGroups => 'Ocultar categorías y grupos';

  @override
  String get hideDockIcon => 'Ocultar icono del muelle';

  @override
  String get hideInConversation => 'Esconderse en la conversación';

  @override
  String get hideMessage => 'Esconder';

  @override
  String get historyStaysOnThisDeviceAgentAccessToClipboardContentIs_74a8f236 =>
      'El historial permanece en este dispositivo. El acceso Agent al contenido del portapapeles se controla a continuación.';

  @override
  String get horizontalNudge => 'empujón horizontal';

  @override
  String hoursHCount(Object hours, Object count) {
    return '$hours h · $count';
  }

  @override
  String get httpsExampleComDingdongResourcesJson =>
      'https://example.com/dingdong-resources.json';

  @override
  String get image => 'Imagen';

  @override
  String get imageCache => 'Caché de imagen';

  @override
  String get images => 'Imágenes';

  @override
  String
  get imagesTextAndFilesAreIndependentCleaningThemNeverRemoves_cb27e3f9 =>
      'Las imágenes, el texto y los archivos son independientes. Limpiarlos nunca elimina los archivos permanentes.';

  @override
  String get impeccableProjectHookApprovalRequiredInHooks =>
      'Proyecto impecable Gancho (se requiere aprobación en /hooks)';

  @override
  String get importFromLink => 'Importar desde enlace';

  @override
  String get importHistory => 'Historial de importación';

  @override
  String get importJSONFile => 'Importar archivo JSON';

  @override
  String importLengthResources(Object length) {
    return 'Importar recursos $length';
  }

  @override
  String importedImportedCountSkippedSkippedCount(
    Object importedCount,
    Object skippedCount,
  ) {
    return 'Importado $importedCount; omitido $skippedCount.';
  }

  @override
  String get importedKnowledgeAvailableToAgentContext =>
      'Conocimiento importado disponible para el contexto Agent.';

  @override
  String importedLengthSkippedSkippedCountSuffix(
    Object length,
    Object skippedCount,
    Object suffix,
  ) {
    return 'Importado $length; omitido $skippedCount.$suffix';
  }

  @override
  String get includeAtLeastOneModifierKey =>
      'Incluya al menos una clave modificadora.';

  @override
  String get independentCopiesProtectedFromHistoryCleanup =>
      'Copias independientes protegidas de la limpieza del historial';

  @override
  String get installInAnyOfTheseProjects =>
      'Instalar en cualquiera de estos proyectos.';

  @override
  String get installSkill => 'Instalar Skill';

  @override
  String get installedFromAnOnlineSource =>
      'Instalado desde una fuente en línea';

  @override
  String get installedSkillPackageSKILLMd =>
      'Paquete Skill instalado · SKILL.md';

  @override
  String get installingAndRestarting => 'Instalando y reiniciando...';

  @override
  String get instructions => 'Instrucciones';

  @override
  String issuecountIssueSNeedAttention(Object issueCount) {
    return 'Los problemas de $issueCount necesitan atención';
  }

  @override
  String get issues => 'Asuntos';

  @override
  String get jsonTOMLOrYAMLConfiguration => 'Configuración JSON, TOML o YAML';

  @override
  String get keepDingDongInTheMenuBarWithoutShowingItInTheDock =>
      'Mantenga DingDong en la barra de menú sin mostrarlo en el Dock.';

  @override
  String get keepEditing => 'Sigue editando';

  @override
  String get keepTheSameConversationIDInOneItemShowNAndDoNotIncrease_925894bb =>
      'Mantenga el mismo ID de conversación en un elemento, muestre ×N y no aumente el recuento reciente.';

  @override
  String get keepTheWorkspaceComfortableInYourCurrentDesktop_41d3bc46 =>
      'Mantenga el espacio de trabajo cómodo en su entorno de escritorio actual.';

  @override
  String get keepThisItemEasyToFindAcrossMultipleGroups =>
      'Mantenga este elemento fácil de encontrar en varios grupos.';

  @override
  String get keyboardShortcuts => 'Atajos de teclado';

  @override
  String get knowledge => 'Conocimiento';

  @override
  String
  get knowledgeIsCollectedFromImportsAndAgentContextItCannotBe_08bd7ed0 =>
      'El conocimiento se recopila de las importaciones y del contexto Agent; todavía no se puede crear una nueva creación aquí.';

  @override
  String get knownConfigurationIssues => 'Problemas de configuración conocidos';

  @override
  String get language => 'Idioma';

  @override
  String lastDateTime(Object date, Object time) {
    return 'Último $date $time';
  }

  @override
  String lastReceivedFromSourceAtCompletedAt(
    Object source,
    Object completedAt,
  ) {
    return 'Último recibido de $source en $completedAt';
  }

  @override
  String get latest => 'El último';

  @override
  String get launchAtStartup => 'Lanzar al inicio';

  @override
  String get leaveEmptyToUseTheResourceTitle =>
      'Déjelo vacío para usar el título del recurso.';

  @override
  String lengthDuplicates(Object length) {
    return '$length duplicados';
  }

  @override
  String lengthIDConflicts(Object length) {
    return '$length Conflictos de identificación';
  }

  @override
  String lengthOnlineSourcesChecked(Object length) {
    return '$length fuentes en línea comprobadas';
  }

  @override
  String get lengthRange => 'Rango de longitud';

  @override
  String lengthResults(Object length) {
    return '$length resultados';
  }

  @override
  String lengthSelected(Object length) {
    return '$length seleccionado';
  }

  @override
  String lengthSources(Object length) {
    return 'Fuentes $length';
  }

  @override
  String get libraryMessage => 'Biblioteca';

  @override
  String get libraryWorkspace => 'Espacio de trabajo de la biblioteca';

  @override
  String get libraryWorkspaceShortcut =>
      'Acceso directo al espacio de trabajo de la biblioteca';

  @override
  String get light => 'Luz';

  @override
  String get link => 'Enlace';

  @override
  String get links => 'Campo de golf';

  @override
  String get loadThisResourceWithoutShowingItsNameInTheAgent_ec7e075b =>
      'Cargue este recurso sin mostrar su nombre en la conversación Agent.';

  @override
  String get loaded => 'Cargado';

  @override
  String get loaded2 => 'cargado';

  @override
  String get local => 'Local';

  @override
  String get localAPI => 'Local API';

  @override
  String get localAuthoring => 'Autoría local';

  @override
  String get localData => 'Datos locales';

  @override
  String get localPort => 'Puerto local';

  @override
  String get localServiceUnavailable => 'Servicio local no disponible';

  @override
  String get localServiceVerified => 'Servicio local verificado';

  @override
  String get lowercaseHyphenName => 'nombre-guión-minúscula';

  @override
  String get maintenance => 'Mantenimiento';

  @override
  String get manage => 'Administrar';

  @override
  String get manageAgents => 'Administrar Agents';

  @override
  String get manageCategories => 'Administrar categorías';

  @override
  String get manual => 'Manual';

  @override
  String get markAsUpdated => 'Marcar como actualizado';

  @override
  String get matchAProjectPathRepositoryOrAgentSource =>
      'Haga coincidir una ruta de proyecto, un repositorio o una fuente Agent.';

  @override
  String get matchAnyOfTheseRules => 'Coincide con cualquiera de estas reglas';

  @override
  String get matchedByDescriptionThenLoadedAsACompleteSkillPackage_fa102bfe =>
      'Coincide con la descripción y luego se carga como un paquete Skill completo solo cuando es necesario.';

  @override
  String get matchesEverything => 'Combina con todo';

  @override
  String get maximumCharacters => 'Caracteres máximos';

  @override
  String get maximumDetailedItems => 'Artículos máximos detallados';

  @override
  String get maximumItems => 'Artículos máximos';

  @override
  String get maximumLengthCannotBeNegative =>
      'La longitud máxima no puede ser negativa.';

  @override
  String get mcpAccess => 'Acceso MCP';

  @override
  String get mcpConfigurationIsInvalid => 'La configuración MCP no es válida';

  @override
  String get mcpFooterSymbol => 'MCP símbolo de pie de página';

  @override
  String get mcpSymbol => 'Símbolo MCP';

  @override
  String get menuBarAlertColor => 'Color de alerta de la barra de menú';

  @override
  String get menuBarIconHiddenByTheCameraHousing =>
      'Icono de la barra de menú oculto por la carcasa de la cámara.';

  @override
  String get menuBarMascot => 'Mascota de la barra de menús';

  @override
  String get metadataOnly => 'Solo metadatos';

  @override
  String get minimumCharacters => 'Caracteres mínimos';

  @override
  String get minimumLengthCannotBeNegative =>
      'La longitud mínima no puede ser negativa.';

  @override
  String get minimumLengthCannotExceedMaximumLength =>
      'La longitud mínima no puede exceder la longitud máxima.';

  @override
  String get mockAddAPhoneOriginTextRowWithoutReadingAnyPhone_381a76fb =>
      'MOCK: agrega una fila de texto de origen telefónico sin leer ningún portapapeles del teléfono.';

  @override
  String get mockCreateASmallLocalFileAndShowItsDeviceSource =>
      'MOCK: crea un pequeño archivo local y muestra la fuente del dispositivo.';

  @override
  String get monitorClipboardChanges =>
      'Supervisar los cambios del portapapeles';

  @override
  String get more => 'Más';

  @override
  String get moreActions => 'Más acciones';

  @override
  String get muted => 'Apagado';

  @override
  String get myNote => 'mi nota';

  @override
  String get name => 'Nombre';

  @override
  String get nameMySkillDescriptionUseWhenInstructions =>
      '---\nnombre: mi-skill\ndescripción: Úselo cuando…\n---\n\n# Instrucciones';

  @override
  String get nativeProject => 'Nativo · Proyecto';

  @override
  String get nativeUser => 'Nativo · Usuario';

  @override
  String get needsYourInput => 'Necesita tu aporte';

  @override
  String get needsYourInput2 => 'Necesita tu aporte';

  @override
  String get never => 'Nunca';

  @override
  String get newCategory => 'Nueva categoría';

  @override
  String get newConfiguration => 'Nueva configuración';

  @override
  String get newGroup => 'Nuevo grupo';

  @override
  String get newProjectGroup => 'Nuevo grupo de proyecto';

  @override
  String get newResource => 'Nuevo recurso';

  @override
  String get newTriggerGroup => 'Nuevo grupo de activación';

  @override
  String get newestFirstClickAResumableItemToReturnToItsConversation =>
      'Lo más nuevo primero. Haga clic en un elemento reanudable para regresar a su conversación.';

  @override
  String get noAgentCompletionsYet => 'Aún no se han completado Agent';

  @override
  String get noCategoriesYet => 'Aún no hay categorías';

  @override
  String get noConnectedDevicesYet => 'Aún no hay dispositivos conectados';

  @override
  String get noDeviceIsOnlineConnectOneFirst =>
      'Ningún dispositivo está en línea. Conecte uno primero.';

  @override
  String get noIssuesFound => 'No se encontraron problemas';

  @override
  String get noKnownIssueThisIsNotAConnectionGuarantee =>
      'Ningún problema conocido; esto no es una garantía de conexión';

  @override
  String get noMatchingGroups => 'No hay grupos coincidentes';

  @override
  String get noMatchingResources => 'No hay recursos coincidentes';

  @override
  String get noMatchingSources => 'No hay fuentes coincidentes';

  @override
  String get noMatchingTriggerGroups =>
      'No hay grupos de activadores coincidentes';

  @override
  String get noProjectGroupsYet => 'Aún no hay grupos de proyectos';

  @override
  String get noProjectSelected => 'Ningún proyecto seleccionado';

  @override
  String get noRealAgentCompletionHasBeenReceivedYet =>
      'Aún no se ha recibido ninguna finalización real de Agent';

  @override
  String get noRecentAgentEvents => 'No hay eventos agent recientes';

  @override
  String get noResourceImportsYet => 'Aún no se importan recursos.';

  @override
  String get noSoundSelected => 'Ningún sonido seleccionado';

  @override
  String get noTriggerGroupsYet => 'Aún no hay grupos de activación';

  @override
  String get noUpdateMetadataYet => 'Aún no hay metadatos actualizados';

  @override
  String get notInstalled => 'No instalado';

  @override
  String notInstalledAgentsLength(Object length) {
    return 'No instalado Agents ($length)';
  }

  @override
  String get notVerified => 'No verificado';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get notify => 'Notificar';

  @override
  String get notifyWhenAnAgentFinishesItsCurrentTaskTurn =>
      'Notificar cuando un Agent finaliza su turno de tarea actual.';

  @override
  String get notifyWhenAnAgentIsWaitingForConfirmationAChoiceOrYour_825d0876 =>
      'Notifique cuando un Agent esté esperando confirmación, una elección o su adquisición.';

  @override
  String get nudgeTheTrayMascotLikeAnOverdueReminder =>
      'Empuja a la mascota de la bandeja como si fuera un recordatorio vencido.';

  @override
  String get offByDefaultMetadataStaysAvailableSensitiveRecordsStill_fa1a5f8f =>
      'Desactivado de forma predeterminada. Los metadatos permanecen disponibles; Los registros confidenciales aún requieren una solicitud explícita cuando están habilitados.';

  @override
  String get offline => 'Desconectado';

  @override
  String get onByDefaultSendsOneEventAfterInstallationOrAVersion_153fb4ab =>
      'Activado de forma predeterminada. Envía un evento después de la instalación o una actualización de la versión con un ID de instalación, versión de la aplicación, sistema operativo y arquitectura aleatorios. No se envía actividad, uso de funciones, contenido del portapapeles, archivos ni mensajes Agent. La implementación es de código abierto y puedes desactivarla en cualquier momento.';

  @override
  String get oneWayAutoSend => 'Envío automático unidireccional';

  @override
  String get online => 'En línea';

  @override
  String onlineOnlineTitles(Object onlineTitles) {
    return 'En línea: $onlineTitles';
  }

  @override
  String get onlineSkillUpdated => 'En línea Skill actualizado';

  @override
  String get onlineSync => 'Sincronización en línea';

  @override
  String
  get onlineSyncIsNotReadyInThisWindowReopenResourceManagerAnd_2ceb1f90 =>
      'La sincronización en línea no está lista en esta ventana. Vuelva a abrir el Administrador de recursos e inténtelo de nuevo.';

  @override
  String get onlyActiveInItsConfiguredTriggerScope =>
      'Solo activo en su alcance de activación configurado';

  @override
  String get onlyDingDongSLocalFileReferencesAreRemovedOriginalFiles_aea4cfa6 =>
      'Sólo se eliminan las referencias del archivo local de DingDong. Los archivos y carpetas originales permanecen intactos.';

  @override
  String get onlyExactExistingProjectDirectoriesCanReceiveANative_7c3d0f93 =>
      'Sólo los directorios de proyectos exactos y existentes pueden recibir un Skill nativo.';

  @override
  String get onlyImageCopiesInsideDingDongSCacheAreRemovedSource_28dfcaa2 =>
      'Solo se eliminan las copias de imágenes dentro del caché de DingDong. Las imágenes originales en otros lugares permanecen intactas.';

  @override
  String get onlyTextRecordsStoredByDingDongAreRemoved =>
      'Sólo se eliminan los registros de texto almacenados por DingDong.';

  @override
  String get onlyTheConfiguredPreferredPortIsKnown =>
      'Sólo se conoce el puerto preferido configurado.';

  @override
  String get open => 'Abierto';

  @override
  String get openAgentConversation => 'Abrir conversación Agent';

  @override
  String openCategoryLocation(Object category) {
    return 'Abrir ubicación $category';
  }

  @override
  String get openDingDongDataFolder => 'Abra la carpeta de datos DingDong';

  @override
  String get openDingDongImageCache => 'Abrir caché de imágenes DingDong';

  @override
  String get openFileWithSystemApp =>
      'Abrir archivo con la aplicación del sistema';

  @override
  String get openForDetailsOrRetry =>
      'Abre para más detalles o vuelve a intentarlo.';

  @override
  String get openLinkWithSystemBrowser =>
      'Abrir enlace con el navegador del sistema';

  @override
  String get openOrHideClipboard => 'Abrir u ocultar portapapeles';

  @override
  String get openPathWithSystemApp =>
      'Abrir camino con la aplicación del sistema';

  @override
  String get openPermissionHelper => 'Ayudante de permiso abierto';

  @override
  String get openSettings => 'Abrir configuración';

  @override
  String get openSource => 'Código abierto';

  @override
  String get openTheStandaloneQRDeviceSwitchDisconnectAndDelete_441119af =>
      'Abra el QR independiente, dispositivo, cambie, desconecte y elimine la superficie.';

  @override
  String openTitle(Object title) {
    return 'Abrir $title';
  }

  @override
  String get openedConnectionManager => 'Abierto: administrador de conexiones';

  @override
  String get openedSendToDeviceChooser =>
      'Abierto: selector de envío a dispositivo';

  @override
  String get optional => 'Opcional';

  @override
  String get optional2 => 'Opcional';

  @override
  String get orange => 'Naranja';

  @override
  String get organizeClipboardItem => 'Organizar elemento del portapapeles';

  @override
  String get otherLocalFiles => 'Otros archivos locales';

  @override
  String get otherSettings => 'Otras configuraciones';

  @override
  String get pairATrustedDeviceAndChooseWhatThisComputerSends =>
      'Empareje un dispositivo confiable y elija lo que envía esta computadora.';

  @override
  String get pairingDoesNotCopyContentByItself =>
      'El emparejamiento no copia el contenido por sí solo.';

  @override
  String pairingQRCodeForName(Object name) {
    return 'Emparejamiento del código QR para $name';
  }

  @override
  String get paste => 'Pasta';

  @override
  String get pasteAGitHubSkillRepositoryFolderOrDirectSKILLMdLink_1ee790e1 =>
      'Pegue un repositorio, una carpeta o un enlace directo SKILL.md GitHub Skill.\nEjemplos:\nhttps://github.com/JevonsCode/codex-skills/tree/main/skills/user-taste\nhttps://github.com/mattpocock/skills/tree/main/skills/productivity/grilling';

  @override
  String get pasteAJSONBundleLinkDingDongWillFetchItResolveItsOnline_cb404168 =>
      'Pegue un enlace del paquete JSON. DingDong lo buscará, resolverá sus recursos en línea y mostrará las fuentes para su revisión antes de importar.';

  @override
  String get pasteAsPlainText => 'Pegar como texto sin formato';

  @override
  String get pasteConfig => 'Pegar configuración';

  @override
  String get pasteAgentSetupInstructionDescription =>
      'Pegue esta breve instrucción en un Agent local. Incluye la ruta MCP exacta de esta instalación, conserva la configuración existente y añade la alerta de finalización solo cuando se admite.';

  @override
  String get path => 'Camino';

  @override
  String get permanentArchives => 'Archivos permanentes';

  @override
  String get permanentArchivesAndTheirImageFilesAreProtectedAndWill_889010d8 =>
      'Los archivos permanentes y sus archivos de imágenes están protegidos y permanecerán intactos.';

  @override
  String get permissionGranted => 'Permiso concedido';

  @override
  String get permissionRequired => 'Permiso requerido';

  @override
  String get permissionStatusUnavailable => 'Estado del permiso no disponible';

  @override
  String get pin => 'Alfiler';

  @override
  String get pinInLibrary => 'Pin en la biblioteca';

  @override
  String get pink => 'Rosa';

  @override
  String get pinned => 'Fijado';

  @override
  String get plainText => 'Texto sin formato';

  @override
  String get portChangesApplyTheNextTimeDingDongStarts =>
      'Los cambios de puerto se aplican la próxima vez que se inicie DingDong.';

  @override
  String preferredPortPreferredPortWasUnavailableUsingActualPort(
    Object preferredPort,
    Object actualPort,
  ) {
    return 'El puerto preferido $preferredPort no estaba disponible; utilizando $actualPort.';
  }

  @override
  String get preparingUpdate => 'Preparando actualización…';

  @override
  String get pressAShortcut => 'Presione un atajo...';

  @override
  String get pressToRecordADifferentShortcut =>
      'Presione para grabar un atajo diferente';

  @override
  String get preview => 'Avance';

  @override
  String get previewImageWithSystemApp =>
      'Vista previa de la imagen con la aplicación del sistema';

  @override
  String get previewRealTrayStatesWithoutCreatingHistoryRecords =>
      'Obtenga una vista previa de los estados reales de la bandeja sin crear registros históricos.';

  @override
  String get previewSound => 'Vista previa de sonido';

  @override
  String get priorityFirstMatchWins => 'Prioridad · primer partido gana';

  @override
  String priorityIndexDragToReorder(Object index) {
    return 'Prioridad $index · arrastrar para reordenar';
  }

  @override
  String get privateHistoryMetadata => 'Metadatos del historial privado';

  @override
  String get projectDirectory => 'Directorio de proyectos';

  @override
  String get projectDirectoryEquals => 'Directorio de proyectos · Iguales';

  @override
  String get projectInstallationScope => 'Alcance de instalación del proyecto';

  @override
  String get projectSkillPathIsInvalid =>
      'La ruta del proyecto Skill no es válida';

  @override
  String get prompt => 'Prompt';

  @override
  String get promptFooterSymbol => 'Prompt símbolo de pie de página';

  @override
  String get promptName => 'Nombre Prompt';

  @override
  String get promptSymbol => 'Símbolo Prompt';

  @override
  String get prompts => 'Prompts';

  @override
  String get promptsSkillsMCPResourcesAndTriggerScopes =>
      'Recursos de Prompt, Skill y MCP, y ámbitos de activación';

  @override
  String get protectedData => 'Datos protegidos';

  @override
  String get protectedDataIsNotClearedHere =>
      'Los datos protegidos no se borran aquí';

  @override
  String get purple => 'Púrpura';

  @override
  String get qrCode => 'código qr';

  @override
  String get quickPasteNeedsAccessibilityPermission =>
      'El pegado rápido necesita permiso de accesibilidad.';

  @override
  String get quickPastePermission => 'Permiso de pegado rápido';

  @override
  String get quickPastePermissionGranted =>
      'Permiso de pegado rápido concedido';

  @override
  String get readOnly => 'Sólo lectura';

  @override
  String get recentAgents => 'agents reciente';

  @override
  String get recheckLocalService => 'Vuelva a verificar el servicio local';

  @override
  String get reconnect => 'Reconectar';

  @override
  String get reconnectThisAgent => 'Vuelva a conectar este Agent';

  @override
  String get refreshStatus => 'Actualizar estado';

  @override
  String get regularExpressionIsInvalid => 'La expresión regular no es válida.';

  @override
  String get release => 'Liberar';

  @override
  String get rememberAfterRestart => 'Recordar después de reiniciar';

  @override
  String get removeFromSelection => 'Eliminar de la selección';

  @override
  String get removeRule => 'Eliminar regla';

  @override
  String get reorder => 'Reordenar';

  @override
  String repeatcountNotificationsForThisConversation(Object repeatCount) {
    return '$repeatCount notificaciones para esta conversación';
  }

  @override
  String get reportAProblem => 'Informar un problema';

  @override
  String get repositoryAddress => 'Dirección del repositorio';

  @override
  String get requestAFeature => 'Solicitar una función';

  @override
  String get requiredInstructionsThatAreAppliedAutomaticallyWhenever_7564e51c =>
      'Instrucciones obligatorias que se aplican automáticamente cuando están activas.';

  @override
  String get reset => 'Reiniciar';

  @override
  String get reset2 => 'Reiniciar';

  @override
  String get resetChanges => 'Restablecer cambios';

  @override
  String resetSemanticLabel(Object semanticLabel) {
    return 'Restablecer $semanticLabel';
  }

  @override
  String get resource => 'Recurso';

  @override
  String get resourceActions => 'Acciones de recursos';

  @override
  String get resourceLibrary => 'Biblioteca de recursos';

  @override
  String get resourceLibrary2 => 'Biblioteca de recursos';

  @override
  String get resourceManager => 'Administrador de recursos';

  @override
  String get resources => 'Recursos';

  @override
  String get resourcesBecomeAvailableWhenASelectedGroupMatchesThis_ae977468 =>
      'Los recursos estarán disponibles cuando un grupo seleccionado coincida con este proyecto o fuente Agent.';

  @override
  String get resourcesUsingThisGroupWillBecomeUnrestricted =>
      'Los recursos que utilicen este grupo no tendrán restricciones.';

  @override
  String get restart => 'Reanudar';

  @override
  String get restore => 'Restaurar';

  @override
  String get restoreDefaults => 'Restaurar valores predeterminados';

  @override
  String get restoreOneHistoryItem => 'Restaurar un elemento del historial';

  @override
  String get retentionDays => 'Días de retención';

  @override
  String get returnedAsACandidate => 'regresó como candidato';

  @override
  String get reviewOnlineResources => 'Revisar recursos en línea';

  @override
  String get reviewResourceSyncAgentConfigurationAndAnythingElseThat_a562ea61 =>
      'Revise la sincronización de recursos, la configuración de Agent y cualquier otra cosa que necesite atención.';

  @override
  String
  get reviewTheSkillBeforeInstallingDingDongSavesTheFullFolder_1375b575 =>
      'Revise el Skill antes de instalarlo. DingDong guarda la carpeta completa, incluidos scripts y referencias; las actualizaciones permanecen manuales.';

  @override
  String get richMobileDetail => 'Ricos detalles móviles';

  @override
  String ruleAndItsMatchingConditionsWillBeRemovedClipboardItems_48d9a089(
    Object rule,
  ) {
    return 'Se eliminarán “$rule” y sus condiciones coincidentes. Los elementos del portapapeles no se eliminan.';
  }

  @override
  String get rulesRunFromTopToBottomTheFirstMatchWins =>
      'Las reglas van de arriba a abajo; el primer partido gana.';

  @override
  String get run => 'Correr';

  @override
  String get running => 'Correr…';

  @override
  String get runningTest => 'Prueba de ejecución…';

  @override
  String get runtimeCheck => 'Comprobación de tiempo de ejecución';

  @override
  String get runtimeStatusUnverified =>
      'Estado de tiempo de ejecución no verificado';

  @override
  String get save => 'Ahorrar';

  @override
  String get saveAsPrompt => 'Guardar como prompt';

  @override
  String get saveCategory => 'Guardar categoría';

  @override
  String get saveGroup => 'Guardar grupo';

  @override
  String get saved => 'Guardado';

  @override
  String savedAsSKILLMdNameName(Object name) {
    return 'Guardado como SKILL.md · nombre: $name';
  }

  @override
  String get savedYAMLRevisionsCurrentAdaptersStayIntact =>
      'Revisiones guardadas de YAML; Los adaptadores actuales permanecen intactos';

  @override
  String get saving => 'Ahorro…';

  @override
  String get scanToConnect => 'Escanear para conectar';

  @override
  String get scanToShareClickToEnlarge =>
      'Escanee para compartir · Haga clic para ampliar';

  @override
  String get scanWithTheDeviceYouWantToTrust =>
      'Escanee con el dispositivo en el que desea confiar.';

  @override
  String get scope => 'Alcance';

  @override
  String get scoped => 'Alcance';

  @override
  String get searchClipboard => 'Buscar portapapeles';

  @override
  String get searchClipboardHistory =>
      'Buscar en el historial del portapapeles';

  @override
  String get searchGroups => 'Grupos de búsqueda';

  @override
  String get searchNameOrContent => 'Buscar nombre o contenido';

  @override
  String get searchNamesOrRules => 'Buscar nombres o reglas';

  @override
  String get searchPromptsSkillsAndMCP => 'Buscar Prompts, Skills y MCP';

  @override
  String get searchResources => 'Buscar recursos';

  @override
  String get searchSources => 'Fuentes de búsqueda';

  @override
  String get seeWhatDingDongStoresLocallyAndCleanOnlyTheHistoryYou_a955b365 =>
      'Vea lo que DingDong almacena localmente y limpie solo el historial que elija.';

  @override
  String get selectAConfigurationToInspectOrEdit =>
      'Seleccione una configuración para inspeccionar o editar';

  @override
  String get selectAll => 'Seleccionar todo';

  @override
  String get selectAnItemToPreview =>
      'Seleccione un elemento para obtener una vista previa';

  @override
  String get selectItem => 'Seleccionar elemento';

  @override
  String get selectItem2 => 'Seleccionar elemento';

  @override
  String selectioncountResourcesSelected(Object selectionCount) {
    return 'Recursos $selectionCount seleccionados';
  }

  @override
  String selectioncountSelected(Object selectionCount) {
    return '$selectionCount seleccionado';
  }

  @override
  String semanticlabelWaitingForAShortcut(Object semanticLabel) {
    return '$semanticLabel, esperando un atajo';
  }

  @override
  String get send3 => 'enviar 3';

  @override
  String get sendTestNotification => 'Enviar notificación de prueba';

  @override
  String get sendTheOneLineSetupRequestToEachAffectedAgentMarkIt_3a68e15f =>
      'Envíe la solicitud de configuración de una línea a cada Agent afectado. Márquelo como completo después de que Agent verifique tanto MCP como las alertas de finalización.';

  @override
  String get sendToDevice => 'Enviar al dispositivo';

  @override
  String get sendToDeviceDialog =>
      'Enviar al cuadro de diálogo del dispositivo';

  @override
  String get sensitiveContentHidden => 'Contenido sensible oculto';

  @override
  String get serverName => 'Nombre del servidor';

  @override
  String get serverURL => 'URL del servidor';

  @override
  String get serviceHealth => 'Estado del servicio';

  @override
  String get setTheSystemWidePanelShortcutAndTheShortcutsUsedInside_4f5138fb =>
      'Configure el acceso directo del panel de todo el sistema y los accesos directos utilizados dentro del panel enfocado.';

  @override
  String get settings => 'Ajustes';

  @override
  String get settings2 => 'Ajustes';

  @override
  String get sharedDatabaseFiles => 'Archivos de base de datos compartidos';

  @override
  String shortcutReady(Object shortcut) {
    return '$shortcut listo';
  }

  @override
  String get showCategoriesAndGroups => 'Mostrar categorías y grupos';

  @override
  String get showCategoriesAndGroupsFiltersActive =>
      'Mostrar categorías y grupos (filtros activos)';

  @override
  String get showConversationTokenUsage =>
      'Mostrar el uso de la conversación Token';

  @override
  String get showMessage => 'Espectáculo';

  @override
  String get showPairingQR => 'Mostrar QR de emparejamiento';

  @override
  String get showQRCodeToPairATrustedDevice =>
      'Mostrar código QR para emparejar un dispositivo confiable';

  @override
  String get showTheSleepingMascotBrieflyThenRestoreTheCurrentState =>
      'Muestre brevemente la mascota dormida y luego restablezca el estado actual.';

  @override
  String get shownOnlyWhenCodexClaudeCodeOrPiProvidesExactLocalUsage_7e557397 =>
      'Se muestra solo cuando Codex, Claude Code o Pi proporcionan un uso local exacto. Los Agents no admitidos no se estiman.';

  @override
  String get skill => 'Skill';

  @override
  String get skill2 => 'Skill';

  @override
  String get skillConfigurationIsInvalid =>
      'La configuración Skill no es válida';

  @override
  String get skillFooterSymbol => 'Skill símbolo de pie de página';

  @override
  String get skillMdContent => 'Contenido SKILL.md';

  @override
  String get skillMdNeedsValidNameAndDescriptionFieldsInItsYAML_c05294f5 =>
      'SKILL.md necesita campos de nombre y descripción válidos en su frontmatter YAML.';

  @override
  String get skillName => 'Nombre Skill';

  @override
  String get skillNameConflict => 'Skill conflicto de nombres';

  @override
  String get skillPackageIsMissing => 'Falta el paquete Skill';

  @override
  String get skillSource => 'fuente Skill';

  @override
  String get skillSymbol => 'Símbolo Skill';

  @override
  String get skills => 'Skills';

  @override
  String skippedcountResourcesAlreadyExistAndWillBeSkippedOr_6aa841ce(
    Object skippedCount,
  ) {
    return 'Los recursos $skippedCount ya existen y se omitirán o se marcarán como conflictos.';
  }

  @override
  String get sleepingState => 'estado de sueño';

  @override
  String get sound => 'Sonido';

  @override
  String get source => 'Fuente';

  @override
  String get sourceApplicationRegularExpression =>
      'Expresión regular de la aplicación fuente';

  @override
  String sourceFilterSummary(Object summary) {
    return 'Filtro de fuente: $summary';
  }

  @override
  String get sourceRegex => 'expresión regular de origen';

  @override
  String get sourceURL => 'URL de origen';

  @override
  String get sources => 'Fuentes';

  @override
  String get startDingDongAfterYouSignInToThisComputer =>
      'Inicie DingDong después de iniciar sesión en esta computadora.';

  @override
  String get status => 'Estado';

  @override
  String get stopConnecting => 'dejar de conectar';

  @override
  String get subagentNotifications => 'Notificaciones de subagente';

  @override
  String get system => 'Sistema';

  @override
  String get systemSound => 'sonido del sistema';

  @override
  String get tagsAndAliases => 'Etiquetas y alias';

  @override
  String get taskMatch => 'Coincidencia de tareas';

  @override
  String get testAConciseSummaryPlusALongerMobileDetailBody =>
      'Pruebe un resumen conciso más un cuerpo detallado móvil más largo.';

  @override
  String get testNotificationSent => 'Notificación de prueba enviada';

  @override
  String get testPanel => 'Panel de prueba';

  @override
  String get text => 'Texto';

  @override
  String get textFromPhone => 'Texto desde el teléfono';

  @override
  String get textHistory => 'Historial de texto';

  @override
  String get textIsLargerThan128KiBAndWasNotSent =>
      'El texto tiene más de 128 KiB y no se envió.';

  @override
  String get textLinksCodeCommandsAndRichText =>
      'Texto, enlaces, código, comandos y texto enriquecido';

  @override
  String get theBundledBridgeExposesPromptsSkillsMCPReferencesAnd_a0f4fd67 =>
      'El Bridge incluido expone Prompts, Skills, referencias de MCP y notificaciones mediante JSON-RPC.';

  @override
  String get theCommandBelowUsesTheActualEndpointWhenTheRuntime_0a3909c7 =>
      'El siguiente comando utiliza el punto final real cuando el tiempo de ejecución proporcionó uno.';

  @override
  String get theCompleteSkillPackageCouldNotBeFoundReinstallOrUpdate_2a4648b6 =>
      'No se pudo encontrar el paquete Skill completo. Reinstale o actualice su fuente.';

  @override
  String get theDEVPWAEndpointIsNotConfiguredInThisBuild =>
      'El punto final DEV PWA no está configurado en esta compilación.';

  @override
  String get theDeviceDisconnectedBeforeSending =>
      'El dispositivo se desconectó antes de enviar.';

  @override
  String
  get theEncryptedMessageIsLargerThanThe256KiBRelayLimitAndWas_3231b01c =>
      'El mensaje cifrado supera el límite de retransmisión de 256 KiB y no se envió.';

  @override
  String get theHealthEndpointRespondedSuccessfully =>
      'El punto final /health respondió correctamente.';

  @override
  String get theHelperOpensAccessibilityAndPlacesADraggableDingDong_11660c82 =>
      'El asistente abre Accesibilidad y coloca un DingDong arrastrable al lado. Si \"-\" funciona, elimine la entrada anterior antes de arrastrarla. Si “-” está deshabilitado, arrastre una vez para que esté disponible, elimine la entrada, luego arrastre nuevamente y active DingDong.';

  @override
  String get theInstalledPackageIsReadOnlyReviewTheSourceBefore_d3e0119e =>
      'El paquete instalado es de sólo lectura. Revise la fuente antes de actualizar.';

  @override
  String get theKeyStaysInTheQRWebRTCIsPreferredTheEncryptedRelay_ca235c45 =>
      'La clave se queda en el QR. Se prefiere WebRTC; el respaldo de retransmisión cifrada no almacena contenido.';

  @override
  String get theRuntimeEndpointDidNotPassItsHealthCheck =>
      'El punto final de tiempo de ejecución no pasó su verificación de estado.';

  @override
  String get theSKILLMdMetadataCouldNotBeParsedReviewTheResource_d8ef0c36 =>
      'No se pudieron analizar los metadatos de SKILL.md. Revise el recurso antes de habilitarlo.';

  @override
  String
  get theScopedProjectDirectoryNoLongerExistsOrIsNotAnAbsolute_78de1cff =>
      'El directorio del proyecto con ámbito ya no existe o no es una ruta absoluta.';

  @override
  String get theSourceDidNotReturnAUsableSKILLMdCheckTheRepository_8db02039 =>
      'La fuente no devolvió un SKILL.md utilizable. Verifique la ruta del repositorio y acceda.';

  @override
  String get theTestFailedCheckTheConnectionAndSystemPermissions =>
      'La prueba falló. Verifique la conexión y los permisos del sistema.';

  @override
  String get theme => 'Tema';

  @override
  String get theseResourcesWillBeLoadedFromTheInternetCheckTheSource_08e83c52 =>
      'Estos recursos se cargarán desde Internet. Verifique los enlaces de origen antes de importarlos.';

  @override
  String get thisComputerHost => 'Esta computadora · Anfitrión';

  @override
  String thisComputerName(Object name) {
    return 'Esta computadora → $name';
  }

  @override
  String get thisConflictsWithAnotherDingDongOrSystemShortcut =>
      'Esto entra en conflicto con otro DingDong o acceso directo del sistema.';

  @override
  String get thisContentIsNoLongerAvailableOrCouldNotBeOpened =>
      'Este contenido ya no está disponible o no se pudo abrir.';

  @override
  String get thisContentNoLongerExistsOrCannotBeOpened =>
      'Este contenido ya no existe o no se puede abrir.';

  @override
  String thisConversationHasNotifiedYouRepeatCountTimesAndUsed_3d5931a3(
    Object repeatCount,
    Object totalTokens,
  ) {
    return 'Esta conversación le ha notificado $repeatCount veces y ha utilizado $totalTokens tokens.';
  }

  @override
  String thisGroupContainsCountArchivedCopiesCopiesWithNoOther_d4ba7c7d(
    int count,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count copias archivadas',
      one: '1 copia archivada',
    );
    return 'Este grupo contiene $_temp0. Se eliminan las copias que no tienen ningún otro grupo. El historial del portapapeles nunca cambia.';
  }

  @override
  String get thisMCPResourceCannotBeWrittenToAgentConfigurationUntil_ad7aa3e0 =>
      'Este recurso MCP no se puede escribir en la configuración Agent hasta que se corrija su formato.';

  @override
  String get thisOnlineSkillDoesNotHaveAnAvailableSource =>
      'Este Skill en línea no tiene una fuente disponible.';

  @override
  String thisRemovesCategoryHistoryCategory2CurrentResourcesAnd_a27899ae(
    Object category,
    Object category2,
  ) {
    return 'Esto elimina el historial $category ($category2). Los recursos y la configuración actuales permanecen intactos.';
  }

  @override
  String thisRemovesLengthResourcesFromTheLocalLibrary(Object length) {
    return 'Esto elimina los recursos $length de la biblioteca local.';
  }

  @override
  String thisRemovesOnlyThisPartOfClipboardHistoryCategory(Object category) {
    return 'Esto elimina sólo esta parte del historial del portapapeles ($category).';
  }

  @override
  String get thisRemovesTheResourceFromTheSharedAgentLibrary =>
      'Esto elimina el recurso de la biblioteca agent compartida.';

  @override
  String thisRemovesTitleFromTheLocalResourceLibrary(Object title) {
    return 'Esto elimina \"$title\" de la biblioteca de recursos local.';
  }

  @override
  String get threeAlertBurst => 'Explosión de tres alertas';

  @override
  String get title => 'Título';

  @override
  String get trayMascotPreviewsAreUnavailableOnThisPlatformTheOther_ab13b937 =>
      'Las vistas previas de la mascota de la bandeja no están disponibles en esta plataforma; las otras pruebas de integración siguen estando disponibles.';

  @override
  String get triggerGroups => 'Grupos de activación';

  @override
  String get triggerScope => 'Alcance del disparador';

  @override
  String get triggeredHorizontalNudge => 'Activado: empujón horizontal';

  @override
  String get triggeredSleepingState => 'Activado: estado de sueño';

  @override
  String get trustAndDirectionalSettingsWillBeRevokedPairAgainTo_f59587ea =>
      'Se revocarán las configuraciones de confianza y direccionales. Empareje nuevamente para volver a conectarse.';

  @override
  String get twoDingDongResourcesResolveToTheSameSkillDestination_aac6ae3f =>
      'Dos recursos DingDong se resuelven en el mismo destino Skill. Cambie el nombre o desactive uno de ellos.';

  @override
  String get type => 'Tipo';

  @override
  String get unavailable => 'Indisponible';

  @override
  String get uncategorized => 'Sin categoría';

  @override
  String get unknown => 'Desconocido';

  @override
  String get unknownAgentConversation => 'Conversación Agent desconocida';

  @override
  String get unpin => 'Desprender';

  @override
  String get unrecognizedLocalFilesAreKept =>
      'Se mantienen los archivos locales no reconocidos';

  @override
  String get untitledClipboardItem => 'Elemento del portapapeles sin título';

  @override
  String get upTo7CharactersThisNameIsShownFirstInTheAgent_b892681f =>
      'Hasta 7 caracteres. Este nombre se muestra primero en la conversación Agent; un valor vacío vuelve al título.';

  @override
  String get update => 'ACTUALIZAR';

  @override
  String get updateCheckFailed => 'Error en la comprobación de actualización';

  @override
  String get updateFailed => 'La actualización falló';

  @override
  String get updateLink => 'Enlace de actualización';

  @override
  String updateToVersion(Object version) {
    return 'Actualización a $version';
  }

  @override
  String get updated => 'Actualizado';

  @override
  String get updated2 => 'Actualizado';

  @override
  String get updated3 => 'Actualizado';

  @override
  String updatedTitleFromItsSource(Object title) {
    return 'Actualizado $title desde su fuente.';
  }

  @override
  String get updating => 'Actualizando…';

  @override
  String get updating2 => 'Actualizando…';

  @override
  String get usage => 'Uso';

  @override
  String get usage2 => 'Uso';

  @override
  String get usage3 => 'Uso';

  @override
  String get useALetterNumberF1F12ArrowSpaceOrReturn =>
      'Utilice una letra, un número, F1–F12, una flecha, un espacio o un retorno.';

  @override
  String get useAValidSTDIOOrStreamableHTTPMCPConfiguration =>
      'Utilice una configuración STDIO o Streamable HTTP MCP válida.';

  @override
  String get useRegularExpressionsOnlyWhenTypeAndLengthAreNotEnough =>
      'Utilice expresiones regulares sólo cuando el tipo y la longitud no sean suficientes.';

  @override
  String get used => 'Usado';

  @override
  String get used2 => 'usado';

  @override
  String get usesTheRealLocalDingRouteUnreadBadgeNativeAlertAnd_63a64edd =>
      'Utiliza la ruta /ding local real, credencial no leída, alerta nativa y entrega de teléfono conectado.';

  @override
  String get verifyTheLocalServiceAndInspectRealAgentSignals =>
      'Verifique el servicio local e inspeccione señales Agent reales.';

  @override
  String get verifyingUpdate => 'Verificando actualización...';

  @override
  String get version => 'Versión';

  @override
  String get viewAllRecentAgents => 'Ver todos los agents recientes';

  @override
  String get viewResource => 'Ver recurso';

  @override
  String get visibleForReferenceOnlyTheseItemsCannotBeClearedHere =>
      'Visible sólo como referencia. Estos elementos no se pueden borrar aquí.';

  @override
  String get waitingForTheLoopbackHealthResponse =>
      'Esperando la respuesta de salud del loopback.';

  @override
  String
  get webrtcIsPreferredTheEndToEndEncryptedRelayFallbackStores_816753f3 =>
      'Se prefiere WebRTC; el respaldo de retransmisión cifrado de extremo a extremo no almacena portapapeles, archivos ni contenido Agent.';

  @override
  String get website => 'Sitio web';

  @override
  String get whenDisabledTheNextLaunchStartsWithAnEmptyAgentHistory =>
      'Cuando está deshabilitado, el siguiente inicio comienza con un historial Agent vacío.';

  @override
  String get whenItApplies => 'cuando se aplica';

  @override
  String get whenOffSubagentActivityShowsNoNotificationOrDingDong_ce161d98 =>
      'Cuando está desactivado, la actividad del subagente no muestra ninguna notificación ni sonido DingDong.';

  @override
  String get whenOffTasksStartedInCodexVoiceModeDoNotNotifyOrPlayA_75237958 =>
      'Cuando está desactivado, las tareas iniciadas en el modo de voz Codex no notifican ni reproducen un sonido DingDong.';

  @override
  String get whenToUse => 'cuando usar';

  @override
  String get windowOpacity => 'Opacidad de la ventana';

  @override
  String get workspaceShortcutsApplyOnlyWhileThePanelIsFocused_1b6f2968 =>
      'Los atajos del espacio de trabajo se aplican solo mientras el panel está enfocado. Valores predeterminados: Control+Q/W/E en macOS, Alt+Q/W/E en Windows.';

  @override
  String get youReUpToDate => 'estas al dia';

  @override
  String get yourDevices => 'Tus dispositivos';

  @override
  String get yourEditsHaveNotBeenSavedLeavingThisPageWillDiscardThem =>
      'Tus ediciones no se han guardado. Salir de esta página los descartará.';

  @override
  String get custom => 'Costumbre';

  @override
  String get builtIn => 'Construido en';

  @override
  String get invalidConfiguration => 'Configuración no válida';

  @override
  String get loadExternal => 'Carga externa';

  @override
  String get directoryNotChecked => 'Directorio no verificado';

  @override
  String get directoryNotDetected => 'Directorio no detectado';

  @override
  String get directoryDetected => 'Directorio detectado';

  @override
  String get unsaved => 'No guardado';

  @override
  String get newAgent => 'Nuevo Agent';

  @override
  String get newLabel => 'Nuevo';

  @override
  String get refresh => 'Refrescar';

  @override
  String get versionComparison => 'Comparación de versiones';

  @override
  String get advancedConfig => 'Configuración avanzada';

  @override
  String get deleteThisAdapter => '¿Eliminar este adaptador?';

  @override
  String get restoreBuiltInVersion => '¿Restaurar la versión incorporada?';

  @override
  String get notChecked => 'No comprobado';

  @override
  String get notDetected => 'No detectado';

  @override
  String get detected => 'Detectado';

  @override
  String get managedButDisabled => 'Administrado pero deshabilitado';

  @override
  String get managedAndEnabled => 'Gestionado y habilitado';

  @override
  String get trustedButDisabled => 'Confiable pero deshabilitado';

  @override
  String get trustedAndEnabled => 'Confiable y habilitado';

  @override
  String get checkingCodex => 'Comprobando Codex…';

  @override
  String get trustEnable => 'Confía y habilita';

  @override
  String get checkAgain => 'comprobar de nuevo';

  @override
  String get notDeclared => 'No declarado';

  @override
  String get declared => 'Declarado';

  @override
  String get skillPaths => 'Rutas Skill';

  @override
  String get mcpConfigurationPath => 'Ruta de configuración MCP';

  @override
  String get agentDirectory => 'Directorio Agent';

  @override
  String get invalid => 'Inválido';

  @override
  String get valid => 'Válido';

  @override
  String get adapterDocument => 'Documento adaptador';

  @override
  String get configurationEvidence => 'Evidencia de configuración';

  @override
  String get storedOnThisDevice => 'Almacenado en este dispositivo';

  @override
  String get agentAccess => 'Acceso Agent';

  @override
  String get workspace => 'ESPACIO DE TRABAJO';

  @override
  String get userOverride => 'Anulación de usuario';

  @override
  String get selectAnAgentAdapterOrCreateOne =>
      'Seleccione un adaptador Agent o cree uno.';

  @override
  String get theFileChangedOutsideDingDongWhileYouHaveUnsavedEdits =>
      'El archivo cambió fuera de DingDong mientras tenía ediciones no guardadas.';

  @override
  String
  get directoryDetectionAndDeclaredPathsVerifyRuntimeConnectionsSeparately =>
      'Detección de directorios y rutas declaradas; verificar las conexiones en tiempo de ejecución por separado';

  @override
  String get agentConnectionConfiguration => 'Configuración de conexión Agent';

  @override
  String get aComparisonAppearsAfterTheNextSavedOrExternalEdit =>
      'Aparece una comparación después de la siguiente edición guardada o externa.';

  @override
  String get twoVersionsAgo => 'Hace dos versiones';

  @override
  String get previousVersion => 'Versión anterior';

  @override
  String get newAgentAdapter => 'Nuevo adaptador Agent';

  @override
  String get theCustomYAMLFileWillBeDeletedAgentResourcesWillStopSyncing =>
      'Se eliminará el archivo YAML personalizado. Los recursos Agent dejarán de sincronizarse con este cliente.';

  @override
  String get theUserOverrideWillBeRemovedItsSnapshotsRemainInLocalHistory =>
      'Se eliminará la anulación del usuario. Sus instantáneas quedan en la historia local.';

  @override
  String get connectionHasNotBeenInferred => 'No se ha inferido la conexión';

  @override
  String get agentDirectoryDetectedDoesNotVerifyConnections =>
      'Información verificada: DingDong encontró el directorio del Agent declarado. Detectar un directorio o declarar una ruta no verifica MCP, Hook, Bridge, autenticación ni callbacks de finalización. Usa Conexiones de Agent para verificar la API local en ejecución y las señales de finalización reales.';

  @override
  String get agentDirectoryNotDetectedDoesNotVerifyConnections =>
      'Información verificada: DingDong no encontró el directorio del Agent declarado. Detectar un directorio o declarar una ruta no verifica MCP, Hook, Bridge, autenticación ni callbacks de finalización. Usa Conexiones de Agent para verificar la API local en ejecución y las señales de finalización reales.';

  @override
  String get codexDidNotReturnAVerifiableHookState =>
      'Codex no devolvió un estado de gancho verificable.';

  @override
  String get thisHookIsManagedAndDisabledDingDongCannotChangeIt =>
      'Este Hook está administrado y deshabilitado; DingDong no puede cambiarlo.';

  @override
  String get thisManagedHookIsEnabledAndCanRunAfterTaskCompletion =>
      'Este Hook administrado está habilitado y puede ejecutarse una vez finalizada la tarea.';

  @override
  String get theCurrentHashIsTrustedButThisHookIsDisabled =>
      'El hash actual es confiable, pero este Hook está deshabilitado.';

  @override
  String get codexCanRunDingDongAfterATaskCompletes =>
      'Codex puede ejecutar DingDong una vez completada una tarea.';

  @override
  String get theHookChangedAfterItsLastReviewCheckTheCurrentCommandAnd =>
      'El Hook cambió después de su última revisión. Verifica el comando actual y el hash antes de volver a confiar en él.';

  @override
  String get codexIsBlockingThisHookUntilItsExactCurrentHashIsTrusted =>
      'Codex está bloqueando este Hook hasta que se confíe en su hash actual exacto.';

  @override
  String get aDingDongHookExistsButItsCommandDoesNotExactlyMatchThis =>
      'Existe un gancho DingDong, pero su comando no coincide exactamente con esta aplicación instalada. No se confiaba en ello.';

  @override
  String get theExpectedDingDongStopHookIsNotConfiguredInCodex =>
      'El gancho de parada DingDong esperado no está configurado en Codex.';

  @override
  String get thisCodexBuildCouldNotBeReachedThroughAppServerUseHooks =>
      'No se pudo acceder a esta compilación Codex a través del servidor de aplicaciones. Utilice /hooks para revisar el gancho.';

  @override
  String get selectRefreshToReadTheCurrentStateFromCodex =>
      'Seleccione actualizar para leer el estado actual de Codex.';

  @override
  String get readingTheCurrentHookDefinitionAndTrustStateFromCodex =>
      'Leyendo la definición de Hook actual y el estado de confianza de Codex.';

  @override
  String get verificationFailed => 'La verificación falló';

  @override
  String get changedSinceReview => 'Cambiado desde la revisión';

  @override
  String get trustRequired => 'Se requiere confianza';

  @override
  String get commandMismatch => 'El comando no coincide';

  @override
  String get hookNotConfigured => 'Gancho no configurado';

  @override
  String get codexUnavailable => 'Codex no disponible';

  @override
  String get onlyTheExactHookShownAboveAndItsCurrentHashWillBe =>
      'Solo se confiará en el Hook exacto que se muestra arriba y su hash actual. Un cambio futuro requiere otra revisión.';

  @override
  String get codexCompletionHook => 'Gancho de finalización Codex';

  @override
  String get thisAdapterDoesNotDeclareBothGlobalAndProjectSkillPaths =>
      'Este adaptador no declara rutas Skill globales ni de proyecto.';

  @override
  String get thisAdapterDoesNotDeclareAPromptFile =>
      'Este adaptador no declara un archivo prompt.';

  @override
  String get promptConfigurationPath => 'Ruta de configuración Prompt';

  @override
  String get thisAdapterDoesNotDeclareAnMCPFile =>
      'Este adaptador no declara un archivo MCP.';

  @override
  String get unavailableBecauseTheAdapterIsInvalid =>
      'No disponible porque el adaptador no es válido.';

  @override
  String get yamlStructureAndDeclaredPathsPassedValidation =>
      'La estructura YAML y las rutas declaradas pasaron la validación.';

  @override
  String get detectionIsNotConnectionVerification =>
      'La detección no es verificación de conexión';

  @override
  String agentAdapterCatalogSummary(
    Object configurationCount,
    Object detectedCount,
  ) {
    return '$configurationCount configuraciones · $detectedCount directorios detectados';
  }

  @override
  String agentAdapterCatalogSummaryWithInvalid(
    Object configurationCount,
    Object detectedCount,
    Object invalidCount,
  ) {
    return '$configurationCount configuraciones · $detectedCount directorios detectados · $invalidCount no válidos';
  }

  @override
  String get openClipboard => 'Abrir portapapeles';

  @override
  String get openConnectedDevices => 'Abrir dispositivos conectados';

  @override
  String get clipboardMonitoringOn => 'Supervisión del portapapeles activada';

  @override
  String get clipboardMonitoringPaused =>
      'Supervisión del portapapeles pausada';

  @override
  String get stopMonitoring => 'Detener supervisión';

  @override
  String get startMonitoring => 'Iniciar supervisión';

  @override
  String get quitDingDong => 'Salir de DingDong';

  @override
  String get quitDingDongDev => 'Salir de DingDong DEV';

  @override
  String dingDongUnreadCount(Object count) {
    return 'DingDong · $count sin leer';
  }

  @override
  String get connectedDevicesWindowTitle =>
      'DingDong · Dispositivos conectados';

  @override
  String get settingsWindowTitle => 'DingDong · Ajustes';

  @override
  String get developmentTestPanelWindowTitle =>
      'DingDong DEV · Panel de pruebas';

  @override
  String get resourceManagerWindowTitle => 'DingDong · Gestor de recursos';

  @override
  String connectDingDongToCurrentAgent(String commandPath) {
    return 'Conecta «$commandPath» al Agent actual como servidor MCP STDIO de usuario llamado dingdong y sin argumentos; conserva la configuración existente y verifica dingdong_bridge. Si se admiten Hooks de finalización de usuario, añade para ese evento un comando Hook con el mismo ejecutable y «--notify-stop --source \"<nombre del Agent actual>\"», luego verifica la alerta.';
  }

  @override
  String get about => 'Acerca de';

  @override
  String get timeSingular => 'vez';

  @override
  String get timePlural => 'veces';

  @override
  String get agentNeedsYourAttention => 'Agent necesita tu atención';

  @override
  String get agentCompleted => 'Tarea del Agent completada';

  @override
  String get mobileDevice => 'Dispositivo móvil';

  @override
  String get sharedFile => 'Archivo compartido';

  @override
  String fromDevice(Object name) {
    return 'De $name';
  }

  @override
  String get dingDongComputer => 'Ordenador DingDong';

  @override
  String get currentTask => 'Tarea actual';

  @override
  String sourceCompletedCurrentTask(Object source) {
    return '$source completó la tarea actual';
  }

  @override
  String get devAgentCompletedMessage =>
      'Prueba DEV: el Agent completó la tarea actual';

  @override
  String get devAgentCompletedDetail =>
      'Esta alerta básica de finalización fue creada por el panel de pruebas. No es el resultado de una tarea real del Agent.';

  @override
  String get devCrossDeviceTaskCompletedMessage =>
      'Prueba DEV: tarea multidispositivo completada';

  @override
  String get devCrossDeviceTaskCompletedDetail =>
      'Este detalle de finalización simulado comprueba el texto largo de la tarjeta móvil, el origen, la hora de finalización y los ajustes de vibración. No es el resultado de una tarea real del Agent.';

  @override
  String devRepeatedAlertMessage(Object index) {
    return 'Prueba DEV: alerta repetida $index/3';
  }

  @override
  String get devRepeatedAlertDetail =>
      'Comprueba el contador de elementos no leídos, el orden cronológico y la entrega móvil repetida. Son datos de prueba simulados.';

  @override
  String get devPhoneTextSampleTitle => 'Muestra DEV de texto del teléfono';

  @override
  String get devPhoneTextSampleContent =>
      'Prueba de DingDong DEV: este texto simula contenido pegado en la entrada del teléfono y enviado explícitamente.';

  @override
  String get devTestPhoneSource => 'Del teléfono de prueba DEV';

  @override
  String get devAutoSyncSampleTitle =>
      'Muestra DEV de sincronización automática del ordenador';

  @override
  String get devAutoSyncSampleContent =>
      'Prueba de DingDong DEV: creada en este ordenador y enviada solo a dispositivos conectados con la sincronización automática activada.';

  @override
  String get devTestPanelSource => 'Panel de pruebas de DingDong DEV';

  @override
  String get devManualSendSampleTitle => 'Muestra DEV de envío manual';

  @override
  String get devManualSendSampleContent =>
      'Prueba de DingDong DEV: elige un dispositivo conectado y envía este elemento explícitamente.';

  @override
  String get devPhoneFileBody =>
      'Archivo de prueba de DingDong DEV\n\nEsta muestra local fue creada por el panel de pruebas para simular la selección de un archivo en un teléfono y su envío explícito.\nNo procede de un teléfono real ni contiene contenido real del usuario.\n';

  @override
  String get devPhoneFileSampleTitle =>
      'Muestra de archivo de teléfono de DingDong DEV.txt';

  @override
  String get agentAPI => 'API del Agent';

  @override
  String get audioFiles => 'Archivos de audio';

  @override
  String get chooseSoundFile => 'Elegir sonido';

  @override
  String get importThisFolder => 'Importar esta carpeta';

  @override
  String get importAction => 'Importar';

  @override
  String get exportAction => 'Exportar';

  @override
  String get jsonFiles => 'Archivos JSON';

  @override
  String get jsonFile => 'Archivo JSON';

  @override
  String get categoryRuleKeywordsExample => 'command, alias:build';

  @override
  String get httpsOrGitHubFileURL => 'URL HTTPS o de archivo de GitHub';
}
