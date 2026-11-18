# Guion de prueba · Revisión rápida de Picker

**Estado** · Preparado para una prueba futura. Los 25 casos son fichas ficticias para recrear, sin archivos de imagen asociados. Las columnas de señal y decisión son para quien modera. Durante la prueba se muestran solo las imágenes de muestra y la señal propuesta.

## Preparación

1. Recrear los 25 casos con fotos desechables, capturas creadas para la prueba y documentos inventados. Usar una biblioteca aislada o un prototipo con datos ficticios. Simular iCloud y Pending en la primera prueba.
2. Asignar las imágenes a los casos en el orden de la tabla. Mantener las mismas imágenes, señales, grupos y decisiones iniciales en ambas vistas. El lote de comparación contiene **25 fotos**, algunas agrupadas.
3. Probar primero en el tamaño habitual de ventana. Entre recorridos, restaurar el mismo estado de partida. Con varias personas, alternar el orden de las vistas. Con una sola, tomar la diferencia de tiempo como orientativa por el efecto de aprendizaje.

## Conjunto de 25 fotos

**Pending** significa marcar, sin ejecutar borrado. Se esperan 19 candidatas según la ficha, de las que 12 deberían acabar en Pending, 4 conservadas y 3 en Revisar luego. Las 6 fotos de control no deberían aparecer en la tanda automática inicial.

| Caso | Foto de muestra | Señal esperada | Acción en el ejercicio |
| --- | --- | --- | --- |
| 01 | Captura de una pantalla de bienvenida antigua | Captura | Pending |
| 02 | Captura del estado de una descarga ya completada | Captura | Pending |
| 03 | Captura de una previsión meteorológica pasada | Captura | Pending |
| 04 | Captura de un menú de una app desinstalada | Captura | Pending |
| 05 | Captura repetida de una pantalla de carga | Captura | Pending |
| 06 | Captura de un aviso promocional caducado | Captura | Pending |
| 07 | Captura de una confirmación temporal sin valor | Captura | Pending |
| 08 | Captura de un meme que se quiere guardar | Captura | Conservar |
| 09 | Captura de un justificante que se debe comprobar | Captura y texto, aparece una vez | Revisar luego |
| 10 | Captura de una alerta ficticia, con vista previa en iCloud simulada | Captura y vista previa pendiente | Revisar luego |
| 11 | Foto movida al sacar el móvil del bolsillo | Posible borrosa | Pending |
| 12 | Foto desenfocada de una mesa vacía | Posible borrosa | Pending |
| 13 | Meme borroso que se quiere guardar | Posible borrosa | Conservar |
| 14 | Documento firmado ficticio, útil y legible | Documento | Conservar |
| 15 | Folleto impreso caducado y fotografiado | Documento | Pending |
| 16 | Etiqueta frontal de un router retirado, pareja R | Etiqueta y grupo R | Pending |
| 17 | Otra toma de la misma etiqueta, pareja R | Etiqueta y grupo R | Pending |
| 18 | Etiqueta de un televisor que todavía se usa | Etiqueta | Revisar luego |
| 19 | Etiqueta del PC que se conserva como referencia | Etiqueta | Conservar |
| 20 | Retrato nítido de control | Sin señal prioritaria | Fuera de la tanda |
| 21 | Paisaje enfocado con pocos detalles, de control | Sin señal prioritaria | Fuera de la tanda |
| 22 | Foto con sujeto nítido y fondo desenfocado | Sin señal prioritaria | Fuera de la tanda |
| 23 | Foto enfocada en luz tenue | Sin señal prioritaria | Fuera de la tanda |
| 24 | Foto general del PC, sin etiqueta ni texto visible | Sin señal prioritaria | Fuera de la tanda |
| 25 | Foto de una persona con un pequeño logotipo en la ropa | Sin señal prioritaria | Fuera de la tanda |

## Tareas y resultados esperados

| Tarea | Qué observar | Resultado esperado |
| --- | --- | --- |
| Limpiar capturas | Encontrar los casos 01–07 y apartarlos. Localizar el meme y el justificante. | Pending contiene las siete capturas indicadas. La 08 se conserva. La 09 solo aparece una vez. |
| Comparar el router | Localizar 16 y 17 y abrir la comparación en paralelo. | Se puede marcar ambas por separado o mediante una acción explícita para la pareja. Pending suma exactamente dos fotos. |
| Clasificar los casos difíciles | Revisar 10–15 y 18–19. Probar el botón central en la 10. | El meme y el documento útil se conservan. La 10 puede aplazarse, pero no marcarse sin vista previa. Las dudas quedan accesibles. |
| Comprobar los controles | Marcar una foto de prueba, deshacer, abrir un filtro y volver a la tanda. | La marca se retira al deshacer, y el progreso y la posición se conservan al regresar. El marcado por lote no afecta selecciones fuera del filtro. |
| Cerrar la sesión | Abrir Pending y cancelar la confirmación de borrado. | Quedan las 12 marcas esperadas y las 3 dudas. La cancelación conserva la cola. Ninguna foto se elimina en esta prueba. |

## Registro y criterio de decisión

Anotar por vista el tiempo hasta localizar la pareja y el tiempo total, el número de acciones para las siete capturas, los errores de alcance, los deshacer y las fotos útiles que se marcaron por error. Registrar aparte falsos positivos del análisis en los seis controles. Una señal dudosa puede justificar revisar una foto. Una foto útil marcada sin una decisión deliberada es un fallo del flujo.

La cuadrícula se propone como entrada si reduce las acciones del bloque de capturas. La comparación en tarjetas se mantiene cuando permite resolver la pareja y las dudas sin perder posición. Para pasar a desarrollo, comprobar también que **Revisar luego** no se confunde con **Pending** y que la persona puede anticipar cuántas fotos afecta cada acción.

| Vista | Tiempo hasta pareja | Tiempo total | Acciones para 7 capturas | Errores de alcance | Deshacer | Útiles marcadas por error |
| --- | --- | --- | --- | --- | --- | --- |
| Cuadrícula primero | | | | | | |
| Tarjetas primero | | | | | | |
