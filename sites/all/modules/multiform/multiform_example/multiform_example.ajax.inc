<?php

/**
 * Ajax form page callback.
 */
function multiform_ajax_example_page() {
  return drupal_get_form('multiform_ajax_example_form');
}

/**
 * Ajax form.
 */
function multiform_ajax_example_form($form, &$form_state) {
  $form_state['build_info']['files'][] = drupal_get_path('module', 'multiform_example') . '/multiform_example.ajax.inc';
  $form['dropdown'] = array(
    '#type' => 'select',
    '#title' => t('Ajax demo'),
    '#options' => array(1 => t('First'), 2 => t('Second')),
    '#ajax' => array(
      'callback' => 'multiform_ajax_example_callback',
      'wrapper' => 'multiform-ajax-select-wrapper',
    ),
  );
  $form['text_1'] = array(
    '#type' => 'textfield',
    '#title' => t('Text field'),
    '#required' => TRUE,
    '#prefix' => '<div id="multiform-ajax-select-wrapper">',
    '#suffix' => '</div>',
  );
  return $form;
}

/**
 * Ajax dropdown ajax callback.
 */
function multiform_ajax_example_callback($form, $form_state) {
  $selected = $form_state['values']['dropdown'];
  $form['text_1']['#value'] = $form['dropdown']['#options'][$selected];
  return $form['text_1'];
}
