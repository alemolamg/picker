# Picker · Revisión rápida

Propuesta para macOS. La cuadrícula prepara tandas de hasta 25 candidatas. La vista de tarjetas permite examinar una foto o comparar dos sin salir de la tanda. Ambas comparten selección, decisiones y progreso.

- [Maquetas estáticas de las dos vistas](mockups.html)
- [Guion y conjunto de 25 casos para la prueba](pruebas.md)

## Recorrido

1. Abrir **Revisión rápida** en la barra lateral de Picker. La cuadrícula muestra una tanda de candidatas con el motivo de inclusión. Si hay más resultados, **Siguiente tanda** carga hasta 25 nuevas candidatas con el mismo filtro.
2. Filtrar por **Capturas**, **Posibles borrosas**, **Documentos** o **Etiquetas**, y acotar por fecha. El filtro solo muestra candidatas de la tanda. Cambiar de filtro conserva las decisiones ya tomadas y limpia la selección temporal para que una acción en bloque alcance solo las fotos visibles.
3. Seleccionar varias fotos visibles con clic, ⌘ o un rango con ⇧. **Marcar N para borrar** las envía a la cola **Pending** de Picker. **Conservar** registra la decisión para que esas fotos no se vuelvan a sugerir en Revisión rápida. **Revisar luego** las reserva en una lista desde la que se puede retomar el contexto.
4. Abrir una foto con doble clic o seleccionar dos y pulsar **Comparar dos**. En la comparación se identifica con un borde y con texto qué foto recibirá la acción. Las flechas **← Marcar para borrar** y **→ Conservar** actúan sobre esa foto. **Revisar luego** es un botón central sin flecha asignada. **Deshacer** revierte la última decisión de la sesión y devuelve el foco a su foto.
5. En un grupo de más de dos, **Abrir grupo** lleva al comparador actual. **Marcar grupo entero** es una acción separada y muestra la cantidad antes de enviar las fotos a Pending. Con **Volver a la tanda** se recuperan el filtro, la posición y las decisiones.
6. Revisar **Pending**, donde se pueden retirar marcas, y confirmar el borrado usando el flujo existente de Picker. La revisión rápida no llama a PhotoKit para borrar.

Los nombres de las maquetas están en español para la revisión de diseño. Si la app sigue en inglés al implementar, los nombres serán **Quick Review**, **Review Later**, **Mark for Deletion**, **Keep** y **Undo**. Se conservará **Pending** como nombre de la cola.

## Cómo se forma una tanda

| Señal | Uso propuesto |
| --- | --- |
| Captura de pantalla | Usar la etiqueta de Apple Fotos. Incluir también capturas fuera de grupos. |
| Posible desenfoque | Proponer las fotos con indicios claros de falta de nitidez mediante una señal específica. Calibrarla con fotos enfocadas, desenfocadas y con desenfoque intencionado. |
| Documento o etiqueta | Usar reconocimiento local de texto y su distribución. Varios bloques amplios sugieren un documento. Un bloque compacto junto a un equipo puede sugerir una etiqueta. Si la distinción es débil, mostrar **Foto con texto**. |
| Similares | Usar los grupos existentes para ofrecer una comparación inmediata. Una pareja ocupa una sola tarjeta de comparación y conserva sus dos fotos identificables. |

La vista inicial alterna categorías para que las capturas no ocupen toda la tanda. Cada foto aparece una vez aunque coincida con varias señales. Las fotos ya resueltas y las que están en Pending se excluyen de tandas nuevas. **Revisar luego** mantiene las dudas en su propia lista y permite resolverlas sin perder contexto. Si no hay candidatas suficientes, se muestra una tanda más corta.

Las señales explican por qué aparece una foto. Las decisiones las toma la persona. El análisis propuesto es local y guarda categorías y señales, sin almacenar el texto reconocido. La búsqueda inicial usa categoría y fecha. La búsqueda libre de objetos como «router» o «televisor» queda para evaluar con ejemplos adicionales. [Reconocimiento de texto con Apple Vision](https://developer.apple.com/documentation/vision/recognizing-text-in-images)

### Estados a resolver al prototipar

- Si el análisis aún está en curso, mostrar las capturas disponibles y el estado de las demás categorías.
- Ante una foto de iCloud sin vista previa local, permitir **Revisar luego** y ofrecer cargar esa foto al abrirla. Habilitar **Marcar para borrar** cuando haya una vista previa legible. La navegación no solicita descargas.
- Las flechas solo ejecutan acciones al revisar una tarjeta y cuando el foco está fuera de campos de texto o diálogos. El marcado y la elección activa se indican con texto además de color.
- Antes de aplicar una acción a un lote, mostrar el número de fotos elegibles. Si alguna deja de estar disponible o cambia de grupo, pedir nueva revisión de esa foto. Deshacer solo afecta a decisiones todavía reversibles en Picker.

### Referencias de interacción

La secuencia rápida toma como referencia el gesto de marcado y revisión de Slidebox. La comparación en paralelo y la selección asistida por criterios tienen precedentes en Lightroom. [Slidebox](https://slidebox.co/faq-ios.html) · [Comparación en Lightroom](https://helpx.adobe.com/lightroom/desktop/organize-photos/compare-photos.html) · [Selección asistida en Lightroom Classic](https://helpx.adobe.com/lightroom-classic/desktop/organize-photos-in-lightroom-classic/assisted-culling.html)
