<?php

define('DEFAULT_MULTIFORM_ID', 'multiform');


/**
 * Inititalize multiform settings.
 */
function multiform_init_settings(&$settings) {

  // @todo: Maybe use other technique to generate default #multiform_id
  // to ensure it is unique.
  // Add #multiform_id if not set in settings.
  // #multiform_id is required for theming (for default tpl.php tempalate name).
  $settings += array(
    '#multiform_id' => DEFAULT_MULTIFORM_ID,
  );

  $submits_form = array(
    'form_id' => 'multiform_submits_form',
    'args' => array($settings),
  );

  // Add submits_form to the end of subforms list.
  array_push($settings['#subforms'], $submits_form);

  foreach ($settings['#subforms'] as $k => $subform) {
    $settings['#subforms'][$k] += array(
      'args' => array(),
      '#before_execute' => array(),
      '#after_execute' => array(),
      '#preprocess_form_state' => array(),
    );
  }
}


/**
 * Inititalize multiform form base structure.
 */
function multiform_init_form(&$build_id_hash) {
  $form = element_info('form');

  $form['#id'] = 'multiform';
  $build_id_hash = md5(uniqid(mt_rand(), TRUE));
  $multiform_build_id = 'multiform_settings-' . $build_id_hash;
  $form['multiform_settings_build_id'] = array(
    '#type' => 'hidden',
    '#value' => $multiform_build_id,
    '#id' => $multiform_build_id,
    '#name' => 'multiform_settings_build_id',
    '#attributes' => array(),
  );
  return $form;
}


/**
 * Initialize $subform_state.
 *
 * @subform - subform settings
 */
function multiform_init_subform_state($subform_id, $subform_args, $settings, $subform) {
  // Disable redirect for the given subform. If any redirect is needed,
  // it must be global for multiform.
  $subform_state = array('no_redirect' => TRUE);
  // Prepare form_state for given subform.
  // Set subform arguments if any.
  $subform_state['build_info']['args'] = $subform_args;

  // Add flags to define subforms after submission.
  $subform_state['#multiform'] = TRUE;
  $subform_state['#subform_index'] = $subform_id;

  // Preprocess subform_state
  // In some cases we may need to add some arbitrary data to form_state before
  // form is built (e.g. entity_ui_get_form()).
  // There is no need in all multiform settings here, so it is added later
  // in order not to be confused about #preprocess_form_state usage.
  foreach ($subform['#preprocess_form_state'] as $function) {
    // $form_state should be passed by reference.
    $function($form_state);
  }
  // Add settings for sharedfields.
  $subform_state['#multiform_settings'] = $settings;
  return $subform_state;
}


/**
 * Store $subform_form and $subform_state structure for further
 * processing (delayed submit).
 */
function multiform_delayed_submit_prepare(&$multiform, $subform_form, $subform_state, $subform_id, $unprocessed_subform) {
  // Store data for further processing
  $multiform['#subforms'][$subform_id] = array(
    'form' => $subform_form,
    'form_state' => $subform_state,
    'unprocessed_form' => $unprocessed_subform,
  );
}


/**
 * Execute subform handlers and perform other tasks.
 *
 * Here we pass variable by reference instead of returning array of values.
 */
function multiform_delayed_submit_execute(&$multiform, &$subform_form, &$subform_state, $subform_id) {
  $subform_form = $multiform['#subforms'][$subform_id]['form'];
  $subform_state = $multiform['#subforms'][$subform_id]['form_state'];
  $unprocessed_subform = $multiform['#subforms'][$subform_id]['unprocessed_form'];

  multiform_drupal_process_form_finish($subform_id, $subform_form, $subform_state, $unprocessed_subform);

  // Store data (submit results) for #before_execute and #after_execute hooks.
  // Data can be used/changed in #before_execute and #after_execute hooks.
  // Usually only $form_state is changed in submit handlers.
  // Also there is no trouble if form wasn't submitted. Data isn't used anywhere
  // else except those hooks.
  // Actually, these are needed only if multiform was submitted and validation
  // passed correctly.
  $multiform['#subforms'][$subform_id]['form'] = $subform_form;
  $multiform['#subforms'][$subform_id]['form_state'] = $subform_state;


  // Invoke #after_execute functions for each form after it is submitted.
  // Invoke only in case form was submitted and there are
  // no validation errors (see multiform_drupal_process_form_finish()).
  $subform_settings = $multiform['#subforms'][$subform_id]['#subform_settings'];
  if ($subform_state['executed'] == TRUE) {
    foreach ($subform_settings['#after_execute'] as $function) {
      $function($multiform, $subform_id);
    }
  }
}

/**
 * Auxiliary subform for submits map.
 */
function multiform_submits_form($form, $form_state, $settings) {
  $form = array();
  if (!empty($settings['#submit_map']['#submits'])) {
    foreach ($settings['#submit_map']['#submits'] as $k => $info) {
      $form[$k] = $info;
    }
  }
  return $form;
}


/**
 * Cache mapped submits info and hide them.
 *
 * Cache only if submits map is not empty.
 */
function multiform_cache_prepare($build_id_hash, $settings, &$multiform_form) {
  $cache = array();

  // Actually we don't need to cache settings itself.
  $cache['settings'] = array($settings);

  // @todo: Prepare cache only in case submits map is set.
  $form_keys = array();
  // @todo: Skip submits_map subform
  foreach ($multiform_form['multiform'] as $k => $subform) {
    $form_id = $subform['#form_id'];
    if ($form_id != 'multiform_submits_form') {
      $form_keys[$form_id] = $k;
    }
  }
  foreach ($settings['#subforms'] as $k => $subform) {
    if (!empty($subform['#map']) && isset($form_keys[$subform['form_id']])) {
      $form_key = $form_keys[$subform['form_id']];
      foreach ($subform['#map'] as $m => $map) {
        $key_exists = FALSE;
        $form_key = $form_keys[$subform['form_id']];
        $element = drupal_array_get_nested_value($multiform_form['multiform'][$form_key], $map['#parents'], $key_exists);
        if ($key_exists) {
          $element['#name'] = 'op';
          $settings['#subforms'][$k]['#map'][$m]['#element'] = $element;
          // Hide mapped submit.
          drupal_array_set_nested_value($multiform_form['multiform'][$form_key], array_merge($map['#parents'], array('#printed')), TRUE, TRUE);
        }
      }
    }
  }

  // Set cache.
  cache_set('multiform_settings-' . $build_id_hash, $settings, 'cache', CACHE_TEMPORARY);
}


/**
 * Preprocess _POST and set triggering submits according to submits map.
 */
function multiform_preprocess_post(&$post, $settings) {
  if (isset($post['multiform']['multiform_submits_form'])) {
    if (!empty($post['multiform']['multiform_submits_form']['op'])) {
      if (empty($post['multiform_settings_build_id'])) {
        return;
      }

      $multiform_settings_build_id = $post['multiform_settings_build_id'];
      $cache = cache_get($multiform_settings_build_id, 'cache');
      if (empty($cache)) {
        return;
      }
      $cached_settings = $cache->data;

      // #name of auxiliary submit.
      $name = $post['multiform']['multiform_submits_form']['op'];

      // Identify array key of the triggering submit, if any.
      foreach ($settings['#submit_map']['#submits'] as $k => $data) {
        if ($name == $data['#value']) {
          $key = $k;
          break;
        }
      }
      if (!empty($key)) {
        foreach ($settings['#subforms'] as $k => $data) {
          if (!empty($data['#map'])) {
            $form_id = $data['form_id'];
            foreach ($data['#map'] as $m => $map) {
              if (in_array($key, $map['#triggering_submit'])) {
                $parents = $map['#parents'];
                if (!empty($cached_settings['#subforms'][$k]['#map'][$m]['#element'])) {
                  $element = $cached_settings['#subforms'][$k]['#map'][$m]['#element'];
                  // Set mapped submit's value.
                  $post['multiform'][$form_id][$element['#name']] = $element['#value'];
                }
              }
            }
          }
        }
      }
    }

    // @todo: Check that there is no subform (added by user)
    // with form_id == 'multiform_submits_form' (since it is reserved for submits).
    // Always unset this subform.
    unset($post['multiform']['multiform_submits_form']);
  }
}

